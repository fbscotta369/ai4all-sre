variable "slack_api_url" {
  type        = string
  description = "Slack Webhook URL or API URL"
  default     = ""
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "69.6.0" # Check for a recent version if this fails
  wait       = false    # Avoid timeouts during large chart updates

  # Enable Grafana without password for local development
  set {
    name  = "grafana.grafana\\.ini.auth\\.anonymous.enabled"
    value = "true"
  }
  set {
    name  = "grafana.grafana\\.ini.auth\\.anonymous.org_role"
    value = "Admin"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin123"
  }

  # Enable Sidecars to auto-load Loki DataSources and SRE Dashboards
  set {
    name  = "grafana.sidecar.datasources.enabled"
    value = "true"
  }
  set {
    name  = "grafana.sidecar.dashboards.enabled"
    value = "true"
  }

  # Grafana Resource Limits & Probes (Stability)
  set {
    name  = "grafana.resources.limits.cpu"
    value = "500m"
  }
  set {
    name  = "grafana.resources.limits.memory"
    value = "512Mi"
  }
  set {
    name  = "grafana.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "grafana.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "grafana.readinessProbe.timeoutSeconds"
    value = "5"
  }
  set {
    name  = "grafana.readinessProbe.initialDelaySeconds"
    value = "30"
  }

  # AlertManager Configuration
  set {
    name  = "alertmanager.config.global.resolve_timeout"
    value = "5m"
  }

  set {
    name  = "alertmanager.config.route.group_by"
    value = "{alertname,job}"
  }

  set {
    name  = "alertmanager.config.route.group_wait"
    value = "30s"
  }

  set {
    name  = "alertmanager.config.route.group_interval"
    value = "5m"
  }

  set {
    name  = "alertmanager.config.route.repeat_interval"
    value = "12h"
  }

  set {
    name  = "alertmanager.config.route.receiver"
    value = "goalert"
  }

  set {
    name  = "alertmanager.config.receivers[0].name"
    value = "goalert"
  }

  set {
    name  = "alertmanager.config.receivers[0].webhook_configs[0].url"
    value = "http://goalert.incident-management.svc.cluster.local/api/v2/generic/incoming?token=eb5f27f0-d62f-4c54-99a4-7d3be96fa943"
  }

  set {
    name  = "alertmanager.config.receivers[1].name"
    value = "ai-agent"
  }

  set {
    name  = "alertmanager.config.receivers[1].webhook_configs[0].url"
    value = "http://ai-agent.observability.svc.cluster.local/webhook"
  }

  # Ensure all alerts also go to the AI Agent
  set {
    name  = "alertmanager.config.route.routes[0].receiver"
    value = "ai-agent"
  }

  set {
    name  = "alertmanager.config.route.routes[0].match.severity"
    value = "critical"
  }

  # Prometheus Resource Limits
  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = "1000m"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "1Gi"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "500m"
  }
  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "512Mi"
  }
}

resource "helm_release" "opentelemetry_collector" {
  name       = "otel-collector"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = "0.146.0"

  # Required configuration for image repository
  set {
    name  = "image.repository"
    value = "otel/opentelemetry-collector-contrib"
  }

  # Required configuration for mode
  set {
    name  = "mode"
    value = "daemonset"
  }

  # Simple configuration to receive OTLP and export to Prometheus
  set {
    name  = "config.receivers.otlp.protocols.grpc.endpoint"
    value = "0.0.0.0:4317"
  }
  set {
    name  = "config.receivers.otlp.protocols.http.endpoint"
    value = "0.0.0.0:4318"
  }
}
# --- Centralized Logging (Loki Stack) ---

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = "2.10.2"

  set {
    name  = "loki.persistence.enabled"
    value = "true"
  }

  set {
    name  = "loki.persistence.size"
    value = "5Gi"
  }

  set {
    name  = "promtail.enabled"
    value = "true"
  }
}

# --- AI SRE Agent (AIOps) ---

resource "kubernetes_service_account" "ai_agent" {
  metadata {
    name      = "ai-agent"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "ai_agent_healing" {
  metadata {
    name = "ai-agent-healing"
  }

  rule {
    api_groups = ["apps", ""]
    resources  = ["deployments", "pods", "services", "replicasets"]
    verbs      = ["get", "list", "watch", "patch", "update", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "ai_agent_healing_binding" {
  metadata {
    name = "ai-agent-healing-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.ai_agent_healing.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.ai_agent.metadata[0].name
    namespace = kubernetes_namespace.observability.metadata[0].name
  }
}

resource "kubernetes_config_map" "ai_agent_script" {
  metadata {
    name      = "ai-agent-script"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  data = {
    "ai_agent.py" = file("${path.module}/ai_agent.py")
  }
}

resource "kubernetes_deployment" "ai_agent" {
  metadata {
    name      = "ai-agent"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      app = "ai-agent"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "ai-agent"
      }
    }

    template {
      metadata {
        labels = {
          app = "ai-agent"
        }
        annotations = {
          "linkerd.io/inject" = "enabled"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.ai_agent.metadata[0].name

        container {
          name  = "ai-agent"
          image = "python:3.11-slim"

          command = ["/bin/sh", "-c"]
          args = [
            "pip install requests fastapi uvicorn kubernetes && python /app/ai_agent.py"
          ]

          port {
            container_port = 8000
          }

          env {
            name  = "OLLAMA_URL"
            value = "http://ollama.default.svc.cluster.local:11434/api/generate"
          }

          volume_mount {
            name       = "script-volume"
            mount_path = "/app"
          }
        }

        volume {
          name = "script-volume"
          config_map {
            name = kubernetes_config_map.ai_agent_script.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ai_agent" {
  metadata {
    name      = "ai-agent"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  spec {
    selector = {
      app = "ai-agent"
    }

    port {
      port        = 80
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

# --- SLOs-as-Code (Phase 4) ---

resource "kubernetes_manifest" "slo_rules" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "slo-rules"
      namespace = kubernetes_namespace.observability.metadata[0].name
      labels = {
        release = "kube-prometheus"
      }
    }
    spec = {
      groups = [
        {
          name = "frontend-slos"
          rules = [
            {
              # SLI: Latency < 500ms
              # Calculating the ratio of requests faster than 500ms
              record = "frontend_latency_sli"
              expr   = "sum(rate(grpc_server_handling_seconds_bucket{job=\"frontend\", le=\"0.5\"}[5m])) / sum(rate(grpc_server_handling_seconds_count{job=\"frontend\"}[5m]))"
            },
            {
              # Alert if SLO (99%) is breached
              alert = "FrontendSLOErrorBudgetBurn"
              expr  = "frontend_latency_sli < 0.99"
              for   = "2m"
              labels = {
                severity = "critical"
                team     = "sre"
              }
              annotations = {
                summary     = "Frontend SLO breach: Error Budget burning"
                description = "The percentage of frontend requests faster than 500ms has dropped below 99%."
              }
            }
          ]
        }
      ]
    }
  }
}

# Grafana Datasource for Loki (via Sidecar)
resource "kubernetes_config_map" "loki_datasource" {
  metadata {
    name      = "loki-datasource"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Loki"
          type      = "loki"
          access    = "proxy"
          url       = "http://loki.observability.svc.cluster.local:3100"
          isDefault = false
        }
      ]
    })
  }
}

# Grafana Dashboard for Loki Logs (via Sidecar)
resource "kubernetes_config_map" "loki_dashboard" {
  metadata {
    name      = "loki-log-dashboard"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "loki-logs.json" = jsonencode({
      title = "SRE: Pod Log Search (Loki)"
      panels = [
        {
          title = "Live Pod Logs"
          type  = "logs"
          targets = [
            {
              expr  = "{namespace=~\"online-boutique|observability|incident-management\"}"
              refId = "A"
            }
          ]
          gridPos = { h = 20, w = 24, x = 0, y = 0 }
        }
      ]
    })
  }
}

# Grafana Dashboard for SLOs (via Sidecar)
resource "kubernetes_config_map" "slo_dashboard" {
  metadata {
    name      = "slo-dashboard"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "slo-dashboard.json" = jsonencode({
      title = "SRE: SLO & Error Budgets"
      panels = [
        {
          title = "Frontend Latency SLO (99.0% < 500ms)"
          type  = "stat"
          targets = [
            { expr = "frontend_latency_sli * 100" }
          ]
          fieldConfig = {
            defaults = {
              unit = "percent"
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "red", value = null },
                  { color = "green", value = 99 }
                ]
              }
            }
          }
        }
      ]
    })
  }
}
