resource "kubernetes_namespace" "boutique" {
  metadata {
    name = "online-boutique"
    annotations = {
      "linkerd.io/inject" = "enabled"
    }
  }
}
