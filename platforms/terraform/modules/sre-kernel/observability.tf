variable "slack_api_url" {
  type        = string
  description = "Slack Webhook URL or API URL"
  default     = ""
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus"
  namespace  = kubernetes_namespace.observability.metadata[0].name
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
  # Grafana admin password sourced from Vault-managed Kubernetes Secret
  set {
    name  = "grafana.admin.existingSecret"
    value = "grafana-admin"
  }
  set {
    name  = "grafana.admin.userKey"
    value = "admin-user"
  }
  set {
    name  = "grafana.admin.passwordKey"
    value = "admin-password"
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
  namespace  = kubernetes_namespace.observability.metadata[0].name
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

  # ────────────────────────────────────────────────────────────────────────────
  # Unified OTel Pipeline: Traces + Metrics + Logs
  # Insurance policy against vendor lock-in (Datadog, New Relic, etc.)
  # All telemetry flows through OTel Collector before reaching backends.
  # ────────────────────────────────────────────────────────────────────────────
  values = [
    yamlencode({
      config = {
        receivers = {
          otlp = {
            protocols = {
              grpc = { endpoint = "0.0.0.0:4317" }
              http = { endpoint = "0.0.0.0:4318" }
            }
          }
        }
        processors = {
          memory_limiter = {
            check_interval  = "1s"
            limit_mib       = 512
            spike_limit_mib = 128
          }
          batch = {
            send_batch_size = 1024
            timeout         = "5s"
          }
          # Resource detection for K8s metadata enrichment
          resource = {
            attributes = [
              { key = "service.namespace", from_attribute = "k8s.namespace.name", action = "upsert" }
            ]
          }
        }
        exporters = {
          # Traces → Tempo
          otlp = {
            endpoint = "tempo:4317"
            tls      = { insecure = true }
          }
          # Metrics → Prometheus (remote-write)
          prometheusremotewrite = {
            endpoint = "http://kube-prometheus-prometheus.observability.svc.cluster.local:9090/api/v1/write"
            tls      = { insecure = true }
          }
          # Debug exporter for logs
          debug = {
            verbosity = "basic"
          }
        }
        service = {
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "resource", "batch"]
              exporters  = ["otlp"]
            }
            metrics = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "resource", "batch"]
              exporters  = ["prometheusremotewrite"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "resource", "batch"]
              exporters  = ["debug"]
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
  namespace  = kubernetes_namespace.observability.metadata[0].name
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
    "ai_agent.py" = file("${path.root}/components/ai-agent/ai_agent.py")
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
          name    = "ai-agent"
          image   = "python:3.11-slim"
          command = ["/bin/sh", "-c"]
          args    = ["pip install requests fastapi uvicorn kubernetes redis pydantic && python /app/ai_agent.py"]
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
          # Credentials sourced from Vault-managed Kubernetes Secret
          env {
            name = "REDIS_URL"
            value_from {
              secret_key_ref {
                name = "ai-agent-credentials"
                key  = "redis_url"
              }
            }
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
            name = "MINIO_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = "ai-agent-credentials"
                key  = "minio_access_key"
              }
            }
          }
          env {
            name = "MINIO_SECRET_KEY"
            value_from {
              secret_key_ref {
                name = "ai-agent-credentials"
                key  = "minio_secret_key"
              }
            }
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
    namespace = kubernetes_namespace.observability.metadata[0].name
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
    namespace = kubernetes_namespace.observability.metadata[0].name
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
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "loki-logs.json" = jsonencode({
      title = "SRE: Pod Log Search (Loki)"
      panels = [
        {
          title   = "Live Pod Logs"
          type    = "logs"
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
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "slo-dashboard.json" = jsonencode({
      title = "SRE: SLO & Error Budgets"
      panels = [
        {
          title   = "Frontend Latency SLO (99.0% < 500ms)"
          type    = "stat"
          targets = [{ expr = "frontend_latency_sli * 100" }]
          fieldConfig = {
            defaults = {
              unit = "percent"
              thresholds = {
                mode  = "absolute"
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
    namespace = kubernetes_namespace.observability.metadata[0].name
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
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "e2e-dashboard.json" = jsonencode({
      title = "CTO: E2E Visual Testing & Resilience"
      panels = [
        {
          title   = "Active Chaos Mesh Experiments"
          type    = "table"
          targets = [{ expr = "chaos_mesh_experiments{}", legendFormat = "{{name}}" }]
          gridPos = { h = 10, w = 12, x = 0, y = 0 }
        },
        {
          title   = "Frontend Error Rate"
          type    = "timeseries"
          targets = [{ expr = "sum(rate(grpc_server_handling_seconds_count{job=\"frontend\", grpc_code!=\"OK\"}[1m]))/sum(rate(grpc_server_handling_seconds_count{job=\"frontend\"}[1m])) * 100", legendFormat = "Error Rate %" }]
          gridPos = { h = 10, w = 12, x = 12, y = 0 }
        },
        {
          title   = "Active GoAlert Incidents (AlertManager)"
          type    = "table"
          targets = [{ expr = "ALERTS{alertstate=\"firing\"}" }]
          gridPos = { h = 10, w = 24, x = 0, y = 10 }
        }
      ]
    })
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Dashboard: Error Budget Burn-Rate (SRE Executive Decision Tool)
# When the budget is blown, feature velocity stops — no exceptions.
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_config_map" "error_budget_dashboard" {
  metadata {
    name      = "error-budget-dashboard"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "error-budget.json" = jsonencode({
      title       = "SRE: Error Budget Burn-Rate"
      description = "Tracks SLO error budget consumption across critical services. When remaining budget < 0%, feature releases MUST halt."
      panels = [
        # ── Frontend Availability (SLO: 99%) ──
        {
          title = "Frontend — Remaining Error Budget (%)"
          type  = "gauge"
          targets = [{
            expr         = "1 - ((1 - frontend_success_rate_5m) / (1 - 0.99))"
            legendFormat = "Budget Remaining"
          }]
          fieldConfig = {
            defaults = {
              unit = "percentunit"
              min  = 0
              max  = 1
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "red", value = null },
                  { color = "orange", value = 0.25 },
                  { color = "green", value = 0.50 }
                ]
              }
            }
          }
          gridPos = { h = 8, w = 8, x = 0, y = 0 }
        },
        {
          title = "Frontend — 1h Burn Rate"
          type  = "stat"
          targets = [{
            expr         = "(1 - avg_over_time(frontend_success_rate_5m[1h])) / (1 - 0.99)"
            legendFormat = "1h Burn"
          }]
          fieldConfig = {
            defaults = {
              unit = "percentunit"
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "green", value = null },
                  { color = "orange", value = 1.0 },
                  { color = "red", value = 14.4 }
                ]
              }
            }
          }
          gridPos = { h = 4, w = 4, x = 8, y = 0 }
        },
        {
          title = "Frontend — 6h Burn Rate"
          type  = "stat"
          targets = [{
            expr         = "(1 - avg_over_time(frontend_success_rate_5m[6h])) / (1 - 0.99)"
            legendFormat = "6h Burn"
          }]
          fieldConfig = {
            defaults = {
              unit = "percentunit"
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "green", value = null },
                  { color = "orange", value = 1.0 },
                  { color = "red", value = 6.0 }
                ]
              }
            }
          }
          gridPos = { h = 4, w = 4, x = 12, y = 0 }
        },
        {
          title = "Frontend — 3d Burn Rate"
          type  = "stat"
          targets = [{
            expr         = "(1 - avg_over_time(frontend_success_rate_5m[3d])) / (1 - 0.99)"
            legendFormat = "3d Burn"
          }]
          fieldConfig = {
            defaults = {
              unit = "percentunit"
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "green", value = null },
                  { color = "orange", value = 0.5 },
                  { color = "red", value = 1.0 }
                ]
              }
            }
          }
          gridPos = { h = 4, w = 4, x = 16, y = 0 }
        },
        # ── Frontend Burn Over Time ──
        {
          title = "Frontend — Availability Over Time"
          type  = "timeseries"
          targets = [
            { expr = "frontend_success_rate_5m * 100", legendFormat = "Availability %" },
            { expr = "99", legendFormat = "SLO Target (99%)" }
          ]
          fieldConfig = { defaults = { unit = "percent" } }
          gridPos     = { h = 8, w = 12, x = 0, y = 8 }
        },
        # ── PaymentService Availability (SLO: 99.9%) ──
        {
          title = "PaymentService — Remaining Error Budget (%)"
          type  = "gauge"
          targets = [{
            expr         = "1 - ((1 - paymentservice_success_rate_5m) / (1 - 0.999))"
            legendFormat = "Budget Remaining"
          }]
          fieldConfig = {
            defaults = {
              unit = "percentunit"
              min  = 0
              max  = 1
              thresholds = {
                mode = "absolute"
                steps = [
                  { color = "red", value = null },
                  { color = "orange", value = 0.25 },
                  { color = "green", value = 0.50 }
                ]
              }
            }
          }
          gridPos = { h = 8, w = 8, x = 12, y = 8 }
        },
        # ── Decision Banner ──
        {
          title = "🚦 Error Budget Policy"
          type  = "text"
          options = {
            mode    = "markdown"
            content = "## Error Budget Policy\\n\\n| Condition | Action |\\n|:---|:---|\\n| **Budget > 50%** | Normal feature velocity ✅ |\\n| **Budget 25-50%** | Reduce blast radius, extra review gates ⚠️ |\\n| **Budget < 25%** | Feature freeze — reliability engineering only 🛑 |\\n| **Budget exhausted** | All hands on reliability. P0 incident declared. 🚨 |"
          }
          gridPos = { h = 6, w = 24, x = 0, y = 16 }
        }
      ]
    })
  }
}
