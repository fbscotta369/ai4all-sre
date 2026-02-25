resource "kubernetes_namespace" "chaos" {
  metadata {
    name = "chaos-testing"
  }
}

resource "helm_release" "chaos_mesh" {
  name       = "chaos-mesh"
  namespace  = kubernetes_namespace.chaos.metadata[0].name
  repository = "https://charts.chaos-mesh.org"
  chart      = "chaos-mesh"
  version    = "2.7.0" 

  set {
    name  = "dashboard.create"
    value = "true"
  }

  set {
    name  = "chaosDaemon.runtime"
    value = "containerd"
  }
  
  set {
    name  = "chaosDaemon.socketPath"
    value = "/run/k3s/containerd/containerd.sock"
  }
}

# 1. Randomly kill 1 frontend pod every 2 minutes for 1 minute
resource "kubernetes_manifest" "frontend_podkill" {
  depends_on = [helm_release.chaos_mesh]
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "Schedule"
    metadata = {
      name      = "kill-frontend"
      namespace = "chaos-testing"
    }
    spec = {
      schedule = "@every 2m"
      type     = "PodChaos"
      podChaos = {
        action = "pod-kill"
        mode   = "one"
        selector = {
          namespaces = ["online-boutique"]
          labelSelectors = {
            "app" = "frontend"
          }
        }
      }
    }
  }
}

# 2. Inject 500ms network latency into frontend outbound calls to recommendation service
resource "kubernetes_manifest" "frontend_latency" {
  depends_on = [helm_release.chaos_mesh]
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "Schedule"
    metadata = {
      name      = "frontend-latency"
      namespace = "chaos-testing"
    }
    spec = {
      schedule = "@every 5m"
      type     = "NetworkChaos"
      networkChaos = {
        action = "delay"
        mode   = "all"
        selector = {
          namespaces = ["online-boutique"]
          labelSelectors = {
            "app" = "frontend"
          }
        }
        delay = {
          latency = "500ms"
        }
      }
    }
  }
}

# 3. Simulate high CPU on the frontend to trigger the OneUptime Alert!
resource "kubernetes_manifest" "frontend_cpu_spike" {
  depends_on = [helm_release.chaos_mesh]
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "Schedule"
    metadata = {
      name      = "frontend-cpu-spike"
      namespace = "chaos-testing"
    }
    spec = {
      schedule = "@every 10m"
      type     = "StressChaos"
      stressChaos = {
        mode = "all"
        selector = {
          namespaces = ["online-boutique"]
          labelSelectors = {
            "app" = "frontend"
          }
        }
        stressors = {
          cpu = {
            workers = 2
            load    = 100
          }
        }
      }
    }
  }
}
# --- Chaos Mesh RBAC for Dashboard ---

resource "kubernetes_service_account" "chaos_admin" {
  metadata {
    name      = "chaos-admin"
    namespace = "default"
  }
}

resource "kubernetes_role" "chaos_admin_role" {
  metadata {
    name      = "chaos-admin-role"
    namespace = "default"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "namespaces"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["chaos-mesh.org"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch", "update"]
  }
}

resource "kubernetes_role_binding" "chaos_admin_binding" {
  metadata {
    name      = "chaos-admin-binding"
    namespace = "default"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.chaos_admin.metadata[0].name
    namespace = "default"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.chaos_admin_role.metadata[0].name
  }
}

output "chaos_mesh_token_command" {
  value       = "kubectl create token ${kubernetes_service_account.chaos_admin.metadata[0].name} -n default"
  description = "Command to generate a login token for Chaos Mesh"
}
