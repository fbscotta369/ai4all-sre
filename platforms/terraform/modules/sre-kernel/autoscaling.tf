resource "kubernetes_horizontal_pod_autoscaler_v2" "paymentservice_hpa" {
  metadata {
    name      = "paymentservice-hpa"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
  }

  spec {
    max_replicas = 5
    min_replicas = 1

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "paymentservice"
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}
