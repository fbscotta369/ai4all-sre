resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.1" # Stable current version

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
}

resource "kubernetes_namespace" "trivy" {
  metadata {
    name = "trivy-system"
  }
}

resource "helm_release" "trivy" {
  name       = "trivy-operator"
  namespace  = kubernetes_namespace.trivy.metadata[0].name
  repository = "https://aquasecurity.github.io/helm-charts/"
  chart      = "trivy-operator"
  version    = "0.24.1" # Check for a recent version during plan

  set {
    name  = "trivy.ignoreUnfixed"
    value = "true"
  }

  set {
    name  = "trivy.resources.limits.memory"
    value = "2Gi"
  }

  set {
    name  = "trivy.resources.requests.memory"
    value = "256Mi"
  }
}
