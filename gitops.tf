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

  # Set admin password to 'admin123'
  # Hash generated via python-bcrypt
  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = "$2b$12$sH.HE0ZxAr2k/OkiXmLrMeSa77jKhqSx5shk1N5IVQ2rey7q9OapK"
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
  version    = "0.24.1" # Reverted to stable; 0.32.0 had CRD mismatches

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

  set {
    name  = "trivy.scanJobsConcurrentLimit"
    value = "2" # Proactive: Limit concurrency to prevent DB locking on local cluster
  }
}

resource "kubernetes_namespace" "keda" {
  metadata {
    name = "keda"
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  namespace  = kubernetes_namespace.keda.metadata[0].name
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.14.0"
  timeout    = 600
  wait       = true
}

# Fix for KEDA Metrics Server crashing on minimal/custom clusters (like K3s 1.34+)
# Missing the default 'extension-apiserver-authentication-reader' Role in kube-system
resource "kubernetes_role" "keda_auth_reader" {
  metadata {
    name      = "extension-apiserver-authentication-reader"
    namespace = "kube-system"
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["extension-apiserver-authentication"]
    verbs          = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "keda_auth_reader_binding" {
  metadata {
    name      = "keda-metrics-auth-reader"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.keda_auth_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "keda-metrics-server"
    namespace = kubernetes_namespace.keda.metadata[0].name
  }
}

resource "kubernetes_manifest" "argocd_app_boutique" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "ai4all-sre"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/fbscotta369/ai4all-sre.git"
        path           = "apps/online-boutique"
        targetRevision = "HEAD"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "online-boutique"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "Replace=true"
        ]
      }
    }
  }
  depends_on = [helm_release.argocd]
}
