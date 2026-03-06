resource "kubernetes_horizontal_pod_autoscaler_v2" "paymentservice_hpa" {
  metadata {
    name      = "paymentservice-hpa"
    namespace = "online-boutique"
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
          type               = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}
