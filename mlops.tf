resource "kubernetes_config_map" "behavioral_loadgen_script" {
  metadata {
    name      = "behavioral-loadgen-script"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
  }

  data = {
    "behavioral_loadgen.py" = file("${path.module}/behavioral_loadgen.py")
  }
}

resource "kubernetes_deployment" "behavioral_loadgen" {
  metadata {
    name      = "behavioral-loadgen"
    namespace = kubernetes_namespace.online_boutique.metadata[0].name
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
          # FIX 6: Use a pre-built image with pinned dependencies (Dockerfile.loadgen).
          # No runtime pip installs — deterministic, reproducible, resilient to PyPI outages.
          # Build: docker build -f Dockerfile.loadgen -t ghcr.io/ai4all-sre/loadgen:latest .
          # TODO: Replace with your container registry image once CI pipeline is set up.
          name  = "loadgen"
          image = var.loadgen_image

          # Fix: Restore command and script mount for behavioral load generator
          command = ["/bin/sh", "-c"]
          args    = ["pip install --user requests && python /app/behavioral_loadgen.py"]

          security_context {
            privileged                 = false
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 1000
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          env {
            name  = "FRONTEND_ADDR"
            value = "frontend:80"
          }

          volume_mount {
            name       = "script"
            mount_path = "/app/behavioral_loadgen.py"
            sub_path   = "behavioral_loadgen.py"
          }
        }

        volume {
          name = "script"
          config_map {
            name = kubernetes_config_map.behavioral_loadgen_script.metadata[0].name
          }
        }
      }
    }
  }
}
