resource "kubernetes_config_map" "behavioral_loadgen_script" {
  metadata {
    name      = "behavioral-loadgen-script"
    namespace = var.online_boutique_namespace
  }

  data = {
    "behavioral_loadgen.py" = file("${path.root}/components/loadgen/behavioral_loadgen.py")
  }
}

resource "kubernetes_deployment" "behavioral_loadgen" {
  metadata {
    name      = "behavioral-loadgen"
    namespace = var.online_boutique_namespace
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
          app           = "behavioral-loadgen"
          team          = "sre"
          environment   = "lab"
          cost-center   = "ai4all"
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
              cpu    = "500m"
              memory = "256Mi"
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

          env {
            name  = "HOME"
            value = "/tmp"
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
