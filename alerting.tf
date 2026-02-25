variable "slack_token" {
  type        = string
  description = "Slack Bot User OAuth Token"
  default     = ""
}

variable "slack_client_id" {
  type        = string
  description = "Slack Client ID"
  default     = ""
}

variable "slack_client_secret" {
  type        = string
  description = "Slack Client Secret"
  default     = ""
}

variable "slack_signing_secret" {
  type        = string
  description = "Slack Signing Secret"
  default     = ""
}

resource "kubernetes_namespace" "alerting" {
  metadata {
    name = "incident-management"
  }
}

resource "helm_release" "postgresql" {
  name       = "goalert-db"
  namespace  = kubernetes_namespace.alerting.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  version    = "18.4.1"

  set {
    name  = "auth.postgresPassword"
    value = "goalertpass"
  }
  set {
    name  = "auth.database"
    value = "goalert"
  }
}

resource "kubernetes_deployment" "goalert" {
  metadata {
    name      = "goalert"
    namespace = kubernetes_namespace.alerting.metadata[0].name
    labels = {
      app = "goalert"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "goalert"
      }
    }

    template {
      metadata {
        labels = {
          app = "goalert"
        }
      }

      spec {
        container {
          name  = "goalert"
          image = "goalert/goalert:latest"

          port {
            container_port = 8081
          }

          env {
            name  = "GOALERT_PUBLIC_URL"
            value = "http://localhost:8083"
          }

          env {
            name  = "GOALERT_DB_URL"
            value = "postgres://postgres:goalertpass@goalert-db-postgresql.incident-management.svc.cluster.local:5432/postgres?sslmode=disable"
          }
        }
      }
    }
  }

  depends_on = [helm_release.postgresql]
}

resource "kubernetes_service" "goalert" {
  metadata {
    name      = "goalert"
    namespace = kubernetes_namespace.alerting.metadata[0].name
  }

  spec {
    selector = {
      app = "goalert"
    }

    port {
      port        = 80
      target_port = 8081
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_manifest" "high_cpu_alert" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "online-boutique-alerts"
      namespace = "observability"
      labels = {
        release = "kube-prometheus"
      }
    }
    spec = {
      groups = [
        {
          name = "online-boutique.rules"
          rules = [
            {
              alert = "FrontendHighCPUUsage"
              expr  = "sum by (namespace) (node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{namespace=\"online-boutique\", pod=~\"frontend-.*\"}) > 0.8"
              for   = "1m"
              labels = {
                severity   = "critical"
                deployment = "frontend"
              }
              annotations = {
                summary     = "Frontend is using too much CPU."
                description = "The frontend pods have been using > 80% CPU for the last 1 minute."
              }
            }
          ]
        }
      ]
    }
  }
}
resource "kubernetes_config_map" "goalert_config_script" {
  metadata {
    name      = "goalert-config-script"
    namespace = kubernetes_namespace.alerting.metadata[0].name
  }

  data = {
    "configure_goalert.py" = file("${path.module}/configure_goalert.py")
  }
}

resource "kubernetes_job" "goalert_iac_config" {
  metadata {
    name      = "goalert-iac-config"
    namespace = kubernetes_namespace.alerting.metadata[0].name
  }

  spec {
    template {
      metadata {}
      spec {
        container {
          name    = "config-runner"
          image   = "python:3.11-slim"
          command = ["/bin/sh", "-c"]
          args = [
            "pip install requests && python /scripts/configure_goalert.py"
          ]

          env {
            name  = "GOALERT_URL"
            value = "http://goalert.incident-management.svc.cluster.local"
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/scripts"
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.goalert_config_script.metadata[0].name
          }
        }
        restart_policy = "OnFailure"
      }
    }
    backoff_limit = 4
  }

  depends_on = [kubernetes_deployment.goalert]
}

resource "kubernetes_ingress_v1" "goalert" {
  metadata {
    name      = "goalert"
    namespace = kubernetes_namespace.alerting.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }

  spec {
    rule {
      host = "goalert.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.goalert.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
