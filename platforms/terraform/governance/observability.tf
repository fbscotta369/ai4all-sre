variable "slack_api_url" {
  type        = string
  description = "Slack Webhook URL or API URL"
  default     = ""
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus"
  namespace  = var.observability_namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "69.6.0"
  wait       = false

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
  set {
    name  = "grafana.sidecar.datasources.enabled"
    value = "true"
  }
  set {
    name  = "grafana.sidecar.dashboards.enabled"
    value = "true"
  }
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
  set {
    name  = "alertmanager.config.route.routes[0].receiver"
    value = "ai-agent"
  }
  set {
    name  = "alertmanager.config.route.routes[0].match.severity"
    value = "critical"
  }
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
  namespace  = var.observability_namespace
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = "0.146.0"

  set {
    name  = "image.repository"
    value = "otel/opentelemetry-collector-contrib"
  }
  set {
    name  = "mode"
    value = "daemonset"
  }

  values = [
    yamlencode({
      config = {
        exporters = {
          otlp = {
            endpoint = "tempo:4317"
            tls      = { insecure = true }
          }
        }
        service = {
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["otlp"]
            }
          }
        }
      }
    })
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = var.observability_namespace
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

  values = [
    yamlencode({
      promtail = {
        config = {
          snippets = {
            pipelineStages = [
              { docker = {} },
              { json = { expressions = { traceID = "http.req.id" } } },
              { labels = { traceID = "" } }
            ]
          }
        }
      }
    })
  ]
}

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = var.observability_namespace
  version    = "1.10.3"

  set {
    name  = "traces.otlp.grpc.enabled"
    value = "true"
  }
  set {
    name  = "traces.otlp.http.enabled"
    value = "true"
  }
}

resource "kubernetes_service_account" "ai_agent" {
  metadata {
    name      = "ai-agent"
    namespace = var.observability_namespace
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
    namespace = var.observability_namespace
  }
}

resource "kubernetes_config_map" "ai_agent_script" {
  metadata {
    name      = "ai-agent-script"
    namespace = var.observability_namespace
  }
  data = {
    "ai_agent.py" = file("${path.root}/components/ai-agent/ai_agent.py")
  }
}

resource "kubernetes_deployment" "ai_agent" {
  metadata {
    name      = "ai-agent"
    namespace = var.observability_namespace
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
          args = ["pip install requests fastapi uvicorn kubernetes redis pydantic && python /app/ai_agent.py"]
          port {
            container_port = 8000
          }
          env {
            name  = "OLLAMA_MODEL"
            value = "llama3"
          }
          env {
            name  = "OLLAMA_URL"
            value = "http://ollama.ollama.svc.cluster.local:11434/api/generate"
          }
          env {
            name  = "OLLAMA_CHAT_URL"
            value = "http://ollama.ollama.svc.cluster.local:11434/api/chat"
          }
          env {
            name  = "REDIS_URL"
            value = "redis://redis.observability.svc.cluster.local:6379/0"
          }
          env {
            name  = "CHROMA_HOST"
            value = "chromadb.observability.svc.cluster.local"
          }
          env {
            name  = "CHROMA_PORT"
            value = "8000"
          }
          env {
            name  = "MINIO_ENDPOINT"
            value = "minio.minio.svc.cluster.local:9000"
          }
          env {
            name  = "MINIO_ACCESS_KEY"
            value = "admin"
          }
          env {
            name  = "MINIO_SECRET_KEY"
            value = "password123!"
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
    namespace = var.observability_namespace
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

resource "kubernetes_manifest" "slo_rules" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "slo-rules"
      namespace = var.observability_namespace
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
              record = "frontend_success_rate_5m"
              expr   = "sum(rate(response_total{namespace=\"online-boutique\",deployment=\"frontend\",classification=\"success\"}[5m])) / sum(rate(response_total{namespace=\"online-boutique\",deployment=\"frontend\"}[5m]))"
            },
            {
              record = "frontend_p95_latency_ms"
              expr   = "histogram_quantile(0.95, sum by (le) (rate(response_latency_ms_bucket{namespace=\"online-boutique\",deployment=\"frontend\"}[5m])))"
            },
            {
              alert = "FrontendAvailabilitySLOBreach"
              expr  = "frontend_success_rate_5m < 0.99"
              for   = "2m"
              labels = {
                severity = "critical"
                team     = "sre"
                slo      = "frontend-availability-99"
              }
              annotations = {
                summary     = "Frontend Availability SLO Breach (target: 99%)"
                description = "Frontend success rate is {{ $value | humanizePercentage }}. Error budget is burning."
                runbook_url = "https://github.com/ai4all-sre/runbooks/blob/main/FrontendAvailabilitySLOBreach.md"
              }
            },
            {
              alert = "FrontendLatencySLOBreach"
              expr  = "frontend_p95_latency_ms > 500"
              for   = "5m"
              labels = {
                severity = "warning"
                team     = "sre"
                slo      = "frontend-latency-p95-500ms"
              }
              annotations = {
                summary     = "Frontend Latency SLO Breach (P95 > 500ms)"
                description = "Frontend P95 latency is {{ $value }}ms. Target: <500ms."
              }
            }
          ]
        },
        {
          name = "backend-slos"
          rules = [
            {
              record = "paymentservice_success_rate_5m"
              expr   = "sum(rate(response_total{namespace=\"online-boutique\",deployment=\"paymentservice\",classification=\"success\"}[5m])) / sum(rate(response_total{namespace=\"online-boutique\",deployment=\"paymentservice\"}[5m]))"
            },
            {
              alert = "PaymentServiceSLOBreach"
              expr  = "paymentservice_success_rate_5m < 0.999"
              for   = "1m"
              labels = {
                severity = "critical"
                team     = "sre"
                slo      = "paymentservice-availability-99.9"
              }
              annotations = {
                summary     = "PaymentService Availability SLO Breach (target: 99.9%)"
                description = "PaymentService success rate: {{ $value | humanizePercentage }}. Immediate investigation required."
                runbook_url = "https://github.com/ai4all-sre/runbooks/blob/main/PaymentServiceSLOBreach.md"
              }
            },
            {
              record = "productcatalog_p95_latency_ms"
              expr   = "histogram_quantile(0.95, sum by (le) (rate(response_latency_ms_bucket{namespace=\"online-boutique\",deployment=\"productcatalogservice\"}[5m])))"
            },
            {
              alert = "ProductCatalogLatencyHigh"
              expr  = "productcatalog_p95_latency_ms > 200"
              for   = "5m"
              labels = {
                severity = "warning"
                team     = "sre"
              }
              annotations = {
                summary     = "ProductCatalog Latency Warning (P95 > 200ms)"
                description = "ProductCatalog P95 latency is {{ $value }}ms."
              }
            }
          ]
        }
      ]
    }
  }
  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map" "loki_datasource" {
  metadata {
    name      = "loki-datasource"
    namespace = var.observability_namespace
    labels    = { grafana_datasource = "1" }
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
          jsonData = {
            derivedFields = [
              {
                datasourceUid = "Tempo"
                matcherRegex  = "traceID=\"([^\"]+)\""
                name          = "TraceID"
                url           = "$${__value.raw}"
              },
              {
                datasourceUid = "Tempo"
                matcherRegex  = "\"http\\.req\\.id\":\"([^\"]+)\""
                name          = "TraceID (JSON)"
                url           = "$${__value.raw}"
              }
            ]
          }
        }
      ]
    })
  }
}

resource "kubernetes_config_map" "tempo_datasource" {
  metadata {
    name      = "tempo-datasource"
    namespace = var.observability_namespace
    labels    = { grafana_datasource = "1" }
  }
  data = {
    "tempo-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Tempo"
          type      = "tempo"
          access    = "proxy"
          url       = "http://tempo.observability.svc.cluster.local:3100"
          isDefault = false
        }
      ]
    })
  }
}

resource "kubernetes_config_map" "loki_dashboard" {
  metadata {
    name      = "loki-log-dashboard"
    namespace = var.observability_namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "loki-logs.json" = jsonencode({
      title = "SRE: Pod Log Search (Loki)"
      panels = [
        {
          title = "Live Pod Logs"
          type  = "logs"
          targets = [{ expr = "{namespace=~\"online-boutique|observability|incident-management\"}", refId = "A" }]
          gridPos = { h = 20, w = 24, x = 0, y = 0 }
        }
      ]
    })
  }
}

resource "kubernetes_config_map" "slo_dashboard" {
  metadata {
    name      = "slo-dashboard"
    namespace = var.observability_namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "slo-dashboard.json" = jsonencode({
      title = "SRE: SLO & Error Budgets"
      panels = [
        {
          title = "Frontend Latency SLO (99.0% < 500ms)"
          type  = "stat"
          targets = [{ expr = "frontend_latency_sli * 100" }]
          fieldConfig = {
            defaults = {
              unit = "percent"
              thresholds = {
                mode = "absolute"
                steps = [{ color = "red", value = null }, { color = "green", value = 99 }]
              }
            }
          }
        }
      ]
    })
  }
}

resource "kubernetes_config_map" "tempo_dashboard" {
  metadata {
    name      = "tempo-tracing-dashboard"
    namespace = var.observability_namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "tempo-traces.json" = jsonencode({
      title = "SRE: Distributed Tracing (Tempo)"
      panels = [
        {
          title      = "Live Trace Search"
          type       = "traces"
          datasource = "Tempo"
          targets    = [{ queryType = "search" }]
          gridPos    = { h = 20, w = 24, x = 0, y = 0 }
        }
      ]
    })
  }
}

resource "kubernetes_config_map" "e2e_dashboard" {
  metadata {
    name      = "e2e-dashboard"
    namespace = var.observability_namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "e2e-dashboard.json" = jsonencode({
      title = "CTO: E2E Visual Testing & Resilience"
      panels = [
        {
          title = "Active Chaos Mesh Experiments"
          type  = "table"
          targets = [{ expr = "chaos_mesh_experiments{}", legendFormat = "{{name}}" }]
          gridPos = { h = 10, w = 12, x = 0, y = 0 }
        },
        {
          title = "Frontend Error Rate"
          type  = "timeseries"
          targets = [{ expr = "sum(rate(grpc_server_handling_seconds_count{job=\"frontend\", grpc_code!=\"OK\"}[1m]))/sum(rate(grpc_server_handling_seconds_count{job=\"frontend\"}[1m])) * 100", legendFormat = "Error Rate %" }]
          gridPos = { h = 10, w = 12, x = 12, y = 0 }
        },
        {
          title = "Active GoAlert Incidents (AlertManager)"
          type  = "table"
          targets = [{ expr = "ALERTS{alertstate=\"firing\"}" }]
          gridPos = { h = 10, w = 24, x = 0, y = 10 }
        }
      ]
    })
  }
}
