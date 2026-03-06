resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.14.4"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Cert-Manager RBAC for Vault
resource "kubernetes_service_account" "cert_manager_vault" {
  metadata {
    name      = "cert-manager-vault"
    namespace = "cert-manager"
  }
}

resource "kubernetes_secret" "cert_manager_vault_token" {
  metadata {
    name      = "cert-manager-vault-token"
    namespace = "cert-manager"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.cert_manager_vault.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# Grant cert-manager permission to create tokens for its vault auth SA
resource "kubernetes_cluster_role" "cert_manager_token_creator" {
  metadata {
    name = "cert-manager-token-creator"
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "cert_manager_token_creator_binding" {
  metadata {
    name = "cert-manager-token-creator-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cert_manager_token_creator.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cert-manager"
    namespace = "cert-manager"
  }
}

# Grant Vault SA permission to review tokens
resource "kubernetes_cluster_role_binding" "vault_auth_delegator" {
  metadata {
    name = "vault-auth-delegator"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "vault"
    namespace = "vault"
  }
}
