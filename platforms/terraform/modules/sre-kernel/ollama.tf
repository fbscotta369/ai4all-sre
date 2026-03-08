resource "kubernetes_persistent_volume_claim" "ollama_storage" {
  metadata {
    name      = "ollama-storage"
    namespace = var.ollama_namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
  wait_until_bound = false
}

resource "kubernetes_deployment" "ollama" {
  metadata {
    name      = "ollama"
    namespace = var.ollama_namespace
    labels = {
      app = "ollama"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "ollama"
      }
    }
    template {
      metadata {
        labels = {
          app = "ollama"
        }
      }
      spec {
        container {
          name  = "ollama"
          image = "ollama/ollama:latest"
          port {
            container_port = 11434
          }
          security_context {
            privileged = false
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
          liveness_probe {
            http_get {
              path = "/api/tags"
              port = 11434
            }
            initial_delay_seconds = 60
            period_seconds        = 20
          }
          readiness_probe {
            http_get {
              path = "/api/tags"
              port = 11434
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
          volume_mount {
            name       = "ollama-storage"
            mount_path = "/root/.ollama"
          }
        }
        volume {
          name = "ollama-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.ollama_storage.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ollama" {
  metadata {
    name      = "ollama"
    namespace = var.ollama_namespace
  }
  spec {
    selector = {
      app = "ollama"
    }
    port {
      port        = 11434
      target_port = 11434
    }
    type = "ClusterIP"
  }
}
