# HashiCorp Vault Infrastructure

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = var.vault_namespace
  version    = "0.28.0"

  set {
    name  = "server.dev.enabled"
    value = "true" # Dev mode for lab simplicity, but with persistent Raft prep
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

# Vault Kubernetes Auth Configuration (Placeholders for manual/scripted setup)
# Note: In a production Tier-1 setup, we would use the Vault Terraform Provider,
# but for this lab, we'll bootstrap the basics via the Helm chart.
