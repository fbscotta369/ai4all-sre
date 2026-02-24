resource "kubernetes_namespace" "boutique" {
  metadata {
    name = "online-boutique"
  }
}

resource "helm_release" "online_boutique" {
  name       = "online-boutique"
  namespace  = kubernetes_namespace.boutique.metadata[0].name
  repository = "https://googlecloudplatform.github.io/microservices-demo"
  chart      = "microservices-demo"
  version    = "0.8.0" # using a stable known version

  set {
    name  = "frontend.externalService"
    value = "true"
  }
}
