# ──────────────────────────────────────────────────────────────────────────────
# HashiCorp Vault Infrastructure
# ──────────────────────────────────────────────────────────────────────────────
#
# ⚠️ LAB LIMITATION: Vault runs in DEV MODE (in-memory storage).
#    - Secrets are LOST on pod restart.
#    - Root token is pre-set (no unseal ceremony).
#    - Acceptable for local development; NOT suitable for production.
#
# PRODUCTION UPGRADE PATH:
#    1. Disable dev mode → enable Raft HA storage (see commented block below)
#    2. Configure KMS auto-unseal (AWS KMS, GCP CKMS, or Azure Key Vault)
#    3. Enable audit logging → forward to Loki via fluentd sidecar
#    4. Deploy Vault CSI Provider for pod-native secret injection
#    5. Configure Kubernetes Auth Method for ServiceAccount-based access
# ──────────────────────────────────────────────────────────────────────────────

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = var.vault_namespace
  version    = "0.28.0"

  set {
    name  = "server.dev.enabled"
    value = "true" # Dev mode for lab simplicity — see upgrade path above
  }

  set {
    name  = "server.standalone.enabled"
    value = "true"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  # Ensure Vault injector has privileged labels for admission control bypass if needed
  set {
    name  = "injector.podLabels.sre-privileged-access"
    value = "true"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# PRODUCTION TEMPLATE: Raft HA + KMS Auto-Unseal
# Uncomment this block and disable dev mode above for production deployment.
# ──────────────────────────────────────────────────────────────────────────────
#
# resource "helm_release" "vault_production" {
#   name       = "vault"
#   repository = "https://helm.releases.hashicorp.com"
#   chart      = "vault"
#   namespace  = var.vault_namespace
#   version    = "0.28.0"
#
#   # ── HA Mode with Raft Storage ──
#   set { name = "server.ha.enabled";  value = "true" }
#   set { name = "server.ha.replicas"; value = "3" }
#   set { name = "server.ha.raft.enabled"; value = "true" }
#   set { name = "server.ha.raft.setNodeId"; value = "true" }
#
#   # ── Persistent Storage ──
#   set { name = "server.dataStorage.enabled"; value = "true" }
#   set { name = "server.dataStorage.size";    value = "10Gi" }
#
#   # ── Auto-Unseal via AWS KMS ──
#   # set { name = "server.extraEnvironmentVars.VAULT_SEAL_TYPE"; value = "awskms" }
#   # set { name = "server.extraEnvironmentVars.AWS_KMS_KEY_ID";  value = "alias/vault-unseal" }
#
#   # ── CSI Driver for Pod Secret Injection ──
#   set { name = "csi.enabled"; value = "true" }
#
#   # ── Audit Logging ──
#   set { name = "server.auditStorage.enabled"; value = "true" }
#   set { name = "server.auditStorage.size";    value = "5Gi" }
#
#   set { name = "injector.enabled"; value = "true" }
#   set { name = "ui.enabled";      value = "true" }
# }

# Vault Kubernetes Auth Configuration (Placeholders for manual/scripted setup)
# Note: In a production Tier-1 setup, we would use the Vault Terraform Provider
# to configure auth methods, policies, and secret engines programmatically.
# For this lab, basics are bootstrapped via the Helm chart dev mode.

# ──────────────────────────────────────────────────────────────────────────────
# Vault Secret Bootstrap — ConfigMap + Job
# Seeds all platform secrets into Vault and configures Kubernetes Auth.
# ──────────────────────────────────────────────────────────────────────────────
resource "kubernetes_config_map" "vault_seed_script" {
  metadata {
    name      = "vault-seed-script"
    namespace = var.vault_namespace
  }
  data = {
    "seed_vault_secrets.sh" = file("${path.root}/scripts/internal/seed_vault_secrets.sh")
  }
  depends_on = [helm_release.vault]
}

resource "kubernetes_job" "vault_bootstrap" {
  metadata {
    name      = "vault-bootstrap"
    namespace = var.vault_namespace
  }
  spec {
    backoff_limit = 3
    template {
      metadata {
        labels = { app = "vault-bootstrap" }
      }
      spec {
        restart_policy       = "OnFailure"
        service_account_name = "vault"
        container {
          name    = "vault-seeder"
          image   = "hashicorp/vault:1.15"
          command = ["/bin/sh", "-c", "chmod +x /scripts/seed_vault_secrets.sh && /scripts/seed_vault_secrets.sh"]
          env {
            name  = "VAULT_ADDR"
            value = "http://vault.${var.vault_namespace}.svc.cluster.local:8200"
          }
          env {
            name  = "VAULT_TOKEN"
            value = "root" # Dev mode root token
          }
          volume_mount {
            name       = "seed-script"
            mount_path = "/scripts"
          }
          resources {
            limits   = { cpu = "200m", memory = "128Mi" }
            requests = { cpu = "100m", memory = "64Mi" }
          }
        }
        volume {
          name = "seed-script"
          config_map {
            name         = kubernetes_config_map.vault_seed_script.metadata[0].name
            default_mode = "0755"
          }
        }
      }
    }
  }
  wait_for_completion = true
  timeouts {
    create = "5m"
  }
  depends_on = [helm_release.vault, kubernetes_config_map.vault_seed_script]
}

# ──────────────────────────────────────────────────────────────────────────────
# Kubernetes Secrets — Centralized credential store
# These replace ALL hardcoded passwords across the platform.
# In production, these would be injected via Vault CSI or Agent Injector.
# ──────────────────────────────────────────────────────────────────────────────

resource "kubernetes_secret" "minio_credentials" {
  metadata {
    name      = "minio-credentials"
    namespace = "minio"
  }
  data = {
    root_user     = "admin"
    root_password = "password123!"
    access_key    = "admin"
    secret_key    = "password123!"
  }
  depends_on = [kubernetes_job.vault_bootstrap]
}

resource "kubernetes_secret" "goalert_db_credentials" {
  metadata {
    name      = "goalert-db-credentials"
    namespace = var.alerting_namespace
  }
  data = {
    postgres_password = "goalertpass"
    connection_url    = "postgres://postgres:goalertpass@goalert-db-postgresql.incident-management.svc.cluster.local:5432/postgres?sslmode=disable"
  }
  depends_on = [kubernetes_job.vault_bootstrap]
}

resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = var.observability_namespace
  }
  data = {
    password = "admin123"
  }
  depends_on = [kubernetes_job.vault_bootstrap]
}

resource "kubernetes_secret" "ai_agent_credentials" {
  metadata {
    name      = "ai-agent-credentials"
    namespace = var.observability_namespace
  }
  data = {
    redis_url        = "redis://redis.observability.svc.cluster.local:6379/0"
    minio_access_key = "admin"
    minio_secret_key = "password123!"
  }
  depends_on = [kubernetes_job.vault_bootstrap]
}
