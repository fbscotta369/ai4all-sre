# Redis — Fix 3: Persistent alert debounce store for the AI Agent
# Replaces the ephemeral /tmp/processed_alerts.json
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = { app = "redis", component = "sre-agent-debounce" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "redis" } }
    template {
      metadata { labels = { app = "redis" } }
      spec {
        container {
          name  = "redis"
          image = "redis:7.2-alpine"
          port { container_port = 6379 }
          args = ["--maxmemory", "64mb", "--maxmemory-policy", "allkeys-lru", "--save", ""]
          resources {
            limits   = { cpu = "200m", memory = "128Mi" }
            requests = { cpu = "50m", memory = "64Mi" }
          }
          liveness_probe {
            exec { command = ["redis-cli", "ping"] }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }
  spec {
    selector = { app = "redis" }
    port {
      port        = 6379
      target_port = 6379
    }
    type = "ClusterIP"
  }
}

# MinIO — Fix 8 + Fix 12: Remote state backend + post-mortem persistence store

# Secret must exist before deployment (avoids cross-module dependency)
resource "kubernetes_secret" "minio_credentials" {
  metadata {
    name      = "minio-credentials"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }
  data = {
    root_user     = "admin"
    root_password = "password123!"
    access_key    = "admin"
    secret_key    = "password123!"
  }
}

resource "kubernetes_deployment" "minio" {
  metadata {
    name      = "minio"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels    = { app = "minio" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "minio" } }
    template {
      metadata { labels = { app = "minio" } }
      spec {
        container {
          name  = "minio"
          image = "quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z"
          args  = ["server", "/data", "--console-address", ":9001"]
          port {
            name           = "api"
            container_port = 9000
          }
          port {
            name           = "console"
            container_port = 9001
          }
          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = "minio-credentials"
                key  = "root_user"
              }
            }
          }
          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = "minio-credentials"
                key  = "root_password"
              }
            }
          }
          resources {
            limits   = { cpu = "500m", memory = "512Mi" }
            requests = { cpu = "100m", memory = "128Mi" }
          }
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }
        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "minio" {
  metadata {
    name      = "minio"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }
  spec {
    selector = { app = "minio" }
    port {
      name        = "api"
      port        = 9000
      target_port = 9000
    }
    port {
      name        = "console"
      port        = 9001
      target_port = 9001
    }
    type = "ClusterIP"
  }
}

# ChromaDB — Fix 12: Vector database for RAG post-mortem retrieval
resource "kubernetes_deployment" "chromadb" {
  metadata {
    name      = "chromadb"
    namespace = kubernetes_namespace.observability.metadata[0].name
    labels    = { app = "chromadb", component = "rag-vector-store" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "chromadb" } }
    template {
      metadata { labels = { app = "chromadb" } }
      spec {
        container {
          name  = "chromadb"
          image = "ghcr.io/chroma-core/chroma:0.4.24"
          port { container_port = 8000 }
          env {
            name  = "IS_PERSISTENT"
            value = "TRUE"
          }
          env {
            name  = "PERSIST_DIRECTORY"
            value = "/chroma/data"
          }
          resources {
            limits   = { cpu = "1000m", memory = "1Gi" }
            requests = { cpu = "200m", memory = "256Mi" }
          }
          volume_mount {
            name       = "chroma-data"
            mount_path = "/chroma/data"
          }
          liveness_probe {
            http_get {
              path = "/api/v1/heartbeat"
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 30
          }
        }
        volume {
          name = "chroma-data"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "chromadb" {
  metadata {
    name      = "chromadb"
    namespace = kubernetes_namespace.observability.metadata[0].name
  }
  spec {
    selector = { app = "chromadb" }
    port {
      port        = 8000
      target_port = 8000
    }
    type = "ClusterIP"
  }
}
