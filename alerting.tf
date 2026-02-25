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
              expr  = "sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{namespace=\"online-boutique\", pod=~\"frontend-.*\"}) > 0.8"
              for   = "1m"
              labels = {
                severity = "critical"
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
# --- GoAlert Slack Configuration Automation ---

resource "kubernetes_secret" "slack_secrets" {
  metadata {
    name      = "slack-secrets"
    namespace = kubernetes_namespace.alerting.metadata[0].name
  }

  data = {
    token          = var.slack_token
    client_id      = var.slack_client_id
    client_secret  = var.slack_client_secret
    signing_secret = var.slack_signing_secret
  }
}

resource "kubernetes_job" "goalert_slack_config" {
  metadata {
    name      = "goalert-slack-config"
    namespace = kubernetes_namespace.alerting.metadata[0].name
  }

  spec {
    template {
      metadata {}
      spec {
        container {
          name  = "config-updater"
          image = "goalert/goalert:latest"
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            set -e
            echo "Updating GoAlert Slack configuration..."
            JSON_CONFIG=$(printf '{"Slack": {"Enable": true, "AccessToken": "%s", "ClientID": "%s", "ClientSecret": "%s", "SigningSecret": "%s", "InteractiveMessages": true}}' "$SLACK_TOKEN" "$SLACK_CLIENT_ID" "$SLACK_CLIENT_SECRET" "$SLACK_SIGNING_SECRET")
            echo "$JSON_CONFIG" | goalert set-config --json --db-url "$GOALERT_DB_URL" --allow-empty-data-encryption-key
            echo "Configuration updated successfully."
            EOT
          ]

          env {
            name  = "GOALERT_DB_URL"
            value = "postgres://postgres:goalertpass@goalert-db-postgresql.incident-management.svc.cluster.local:5432/postgres?sslmode=disable"
          }

          env {
            name = "SLACK_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.slack_secrets.metadata[0].name
                key  = "token"
              }
            }
          }
          env {
            name = "SLACK_CLIENT_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.slack_secrets.metadata[0].name
                key  = "client_id"
              }
            }
          }
          env {
            name = "SLACK_CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.slack_secrets.metadata[0].name
                key  = "client_secret"
              }
            }
          }
          env {
            name = "SLACK_SIGNING_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.slack_secrets.metadata[0].name
                key  = "signing_secret"
              }
            }
          }
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 4
  }

  depends_on = [kubernetes_deployment.goalert]
}
