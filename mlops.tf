resource "kubernetes_config_map" "behavioral_loadgen_script" {
  metadata {
    name      = "behavioral-loadgen-script"
    namespace = "online-boutique"
  }

  data = {
    "behavioral_loadgen.py" = file("${path.module}/behavioral_loadgen.py")
  }
}

resource "kubernetes_deployment" "behavioral_loadgen" {
  metadata {
    name      = "behavioral-loadgen"
    namespace = "online-boutique"
    labels = {
      app = "behavioral-loadgen"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "behavioral-loadgen"
      }
    }

    template {
      metadata {
        labels = {
          app = "behavioral-loadgen"
        }
      }

      spec {
        container {
          name  = "loadgen"
          image = "python:3.11-slim"
          
          security_context {
            privileged = false
          }
          
          command = ["/bin/sh", "-c"]
          args = [
            "pip install requests && python /app/behavioral_loadgen.py"
          ]

          env {
            name  = "FRONTEND_ADDR"
            value = "frontend:80"
          }

          volume_mount {
            name       = "script-volume"
            mount_path = "/app"
          }
        }

        volume {
          name = "script-volume"
          config_map {
            name = kubernetes_config_map.behavioral_loadgen_script.metadata[0].name
          }
        }
      }
    }
  }
}
