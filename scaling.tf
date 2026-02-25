resource "kubernetes_horizontal_pod_autoscaler_v2" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace.boutique.metadata[0].name
  }

  spec {
    min_replicas = 3
    max_replicas = 10

    scale_target_ref {
      api_version = "argoproj.io/v1alpha1"
      kind        = "Rollout"
      name        = "frontend"
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "productcatalogservice" {
  metadata {
    name      = "productcatalogservice"
    namespace = kubernetes_namespace.boutique.metadata[0].name
  }

  spec {
    min_replicas = 2
    max_replicas = 8

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "productcatalogservice"
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}
