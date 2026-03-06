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
