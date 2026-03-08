resource "kubernetes_namespace" "linkerd" {
  metadata {
    name = "linkerd"
    labels = {
      "linkerd.io/is-control-plane"          = "true"
      "config.linkerd.io/admission-webhooks" = "disabled"
    }
  }
}

resource "kubernetes_namespace" "kyverno" {
  metadata { name = "kyverno" }
}

resource "kubernetes_namespace" "minio" {
  metadata { name = "minio" }
}

resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}

resource "kubernetes_namespace" "trivy" {
  metadata { name = "trivy-system" }
}

resource "kubernetes_namespace" "keda" {
  metadata { name = "keda" }
}

resource "kubernetes_namespace" "online_boutique" {
  metadata {
    name = "online-boutique"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}

resource "kubernetes_namespace" "ai_lab" {
  metadata { name = "ai-lab" }
}

resource "kubernetes_namespace" "ollama" {
  metadata { name = "ollama" }
}

resource "kubernetes_namespace" "vault" {
  metadata { name = "vault" }
}

resource "kubernetes_namespace" "alerting" {
  metadata { name = "incident-management" }
}

resource "kubernetes_namespace" "chaos" {
  metadata { name = "chaos-testing" }
}

resource "kubernetes_namespace" "observability" {
  metadata { name = "observability" }
}
