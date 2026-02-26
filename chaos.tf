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
    name  = "dashboard.security.rbac"
    value = "false"
  }

  set {
    name  = "controller.podLabels.sre-privileged-access"
    value = "true"
  }

  set {
    name  = "chaosDaemon.podLabels.sre-privileged-access"
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

# 4. DNS Chaos: Intermittent DNS failures for all microservices
resource "kubernetes_manifest" "dns_chaos" {
  depends_on = [helm_release.chaos_mesh]
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "Schedule"
    metadata = {
      name      = "dns-failure-schedule"
      namespace = "chaos-testing"
    }
    spec = {
      schedule = "@every 15m"
      type     = "DNSChaos"
      dnsChaos = {
        action = "error"
        mode   = "all"
        selector = {
          namespaces = ["online-boutique"]
        }
      }
    }
  }
}

# 5. HTTP Chaos: Inject 500 errors into the Product Catalog Service
resource "kubernetes_manifest" "http_chaos" {
  depends_on = [helm_release.chaos_mesh]
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "Schedule"
    metadata = {
      name      = "product-catalog-errors"
      namespace = "chaos-testing"
    }
    spec = {
      schedule = "@every 20m"
      type     = "HTTPChaos"
      httpChaos = {
        mode = "all"
        selector = {
          namespaces = ["online-boutique"]
          labelSelectors = {
            "app" = "productcatalogservice"
          }
        }
        target = "Request"
        port   = 3550
        abort  = true
      }
    }
  }
}

# 6. Disaster Workflow: Sequential Pod Kill then Network Latency
resource "kubernetes_manifest" "disaster_workflow" {
  depends_on = [helm_release.chaos_mesh]
  manifest = {
    apiVersion = "chaos-mesh.org/v1alpha1"
    kind       = "Workflow"
    metadata = {
      name      = "cascading-failure-workflow"
      namespace = "chaos-testing"
    }
    spec = {
      entry = "the-sequence"
      templates = [
        {
          name         = "the-sequence"
          templateType = "Serial"
          children     = ["kill-cart", "wait-60s", "latency-all"]
        },
        {
          name         = "kill-cart"
          templateType = "PodChaos"
          podChaos = {
            action = "pod-kill"
            mode   = "one"
            selector = {
              namespaces     = ["online-boutique"]
              labelSelectors = { "app" = "cartservice" }
            }
          }
        },
        {
          name         = "wait-60s"
          templateType = "Suspend"
          deadline     = "2m"
          suspend = {
            duration = "1m"
          }
        },
        {
          name         = "latency-all"
          templateType = "NetworkChaos"
          networkChaos = {
            action = "delay"
            mode   = "all"
            selector = {
              namespaces = ["online-boutique"]
            }
            delay = {
              latency = "200ms"
            }
          }
        }
      ]
    }
  }
}
# --- Chaos Mesh RBAC for Dashboard ---

resource "kubernetes_service_account" "chaos_admin" {
  metadata {
    name      = "chaos-admin-sre"
    namespace = "default"
  }
}

resource "kubernetes_role" "chaos_admin_role" {
  metadata {
    name      = "chaos-admin-role-sre"
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
    name      = "chaos-admin-binding-sre"
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

# Automated Secret for long-lived ServiceAccount Token (Chaos Dashboard Login)
resource "kubernetes_secret" "chaos_admin_token" {
  metadata {
    name      = "chaos-mesh-token"
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.chaos_admin.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# Dashboard Ingress
resource "kubernetes_ingress_v1" "chaos_dashboard" {
  metadata {
    name      = "chaos-dashboard"
    namespace = kubernetes_namespace.chaos.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }

  spec {
    rule {
      host = "chaos.local"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "chaos-dashboard"
              port {
                number = 2333
              }
            }
          }
        }
      }
    }
  }
}

output "chaos_mesh_token_command" {
  value       = "kubectl get secret chaos-mesh-token -n default -o jsonpath='{.data.token}' | base64 --decode"
  description = "Command to retrieve the long-lived Chaos Mesh login token"
}
