resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno"
  chart            = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  version          = "3.1.4"

  # bitnami/kubectl:1.28.5 was removed from Docker Hub; use alpine/k8s instead.
  # alpine/k8s runs as root, so runAsNonRoot must be disabled for both cleanup jobs.
  set {
    name  = "cleanupJobs.admissionReports.image.registry"
    value = ""
  }
  set {
    name  = "cleanupJobs.admissionReports.image.repository"
    value = "alpine/k8s"
  }
  set {
    name  = "cleanupJobs.admissionReports.image.tag"
    value = "1.28.13"
  }
  set {
    name  = "cleanupJobs.admissionReports.securityContext.runAsNonRoot"
    value = "false"
  }

  set {
    name  = "cleanupJobs.clusterAdmissionReports.image.registry"
    value = ""
  }
  set {
    name  = "cleanupJobs.clusterAdmissionReports.image.repository"
    value = "alpine/k8s"
  }
  set {
    name  = "cleanupJobs.clusterAdmissionReports.image.tag"
    value = "1.28.13"
  }
  set {
    name  = "cleanupJobs.clusterAdmissionReports.securityContext.runAsNonRoot"
    value = "false"
  }
}

# Sample Policy: Disallow Privileged Containers
resource "kubernetes_manifest" "policy_disallow_privileged" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "disallow-privileged-containers"
    }
    spec = {
      validationFailureAction = "Enforce"
      background              = true
      rules = [
        {
          name = "privileged-containers"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          exclude = {
            any = [
              {
                resources = {
                  # Exclude pods that have been explicitly granted privileged access
                  selector = {
                    matchLabels = {
                      "sre-privileged-access" = "true"
                    }
                  }
                }
              },
              {
                resources = {
                  # Exclude all system and SRE lab namespaces from this policy
                  namespaces = [
                    "kube-system",
                    "kyverno",
                    "observability",
                    "incident-management",
                    "chaos-testing",
                    "online-boutique",
                    "argocd",
                    "argo-rollouts",
                    "linkerd",
                    "linkerd-viz",
                    "monitoring",
                  ]
                }
              }
            ]
          }
          validate = {
            message = "Privileged containers are not allowed."
            pattern = {
              spec = {
                containers = [
                  {
                    securityContext = {
                      privileged = false
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }
  depends_on = [helm_release.kyverno]
}

# Sample Policy: Require Resource Limits
resource "kubernetes_manifest" "policy_require_limits" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "require-resource-limits"
    }
    spec = {
      validationFailureAction = "Audit"
      rules = [
        {
          name = "check-resource-limits"
          match = {
            any = [
              {
                resources = {
                  kinds = ["Pod"]
                }
              }
            ]
          }
          validate = {
            message = "CPU and Memory limits are required."
            pattern = {
              spec = {
                containers = [
                  {
                    resources = {
                      limits = {
                        memory = "?*"
                        cpu    = "?*"
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }
  depends_on = [helm_release.kyverno]
}
# Proactive Policy: Inject Resource Limits if missing (Mutation)
resource "kubernetes_manifest" "policy_mutate_limits" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "mutate-resource-limits"
    }
    spec = {
      validationFailureAction = "Audit"
      background              = true
      rules = [
        {
          name = "inject-default-limits"
          match = {
            any = [{ resources = { kinds = ["Pod"] } }]
          }
          exclude = {
            any = [{ resources = { namespaces = ["kube-system", "kyverno", "observability"] } }]
          }
          mutate = {
            patchStrategicMerge = {
              spec = {
                containers = [
                  {
                    "(name)" : "*",
                    resources = {
                      limits = {
                        cpu    = "500m"
                        memory = "256Mi"
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      ]
    }
  }
  depends_on = [helm_release.kyverno]
} # Proactive Policy: Enforce Linkerd Injection (Zero-Trust mTLS)
resource "kubernetes_manifest" "policy_enforce_linkerd" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "enforce-linkerd-injection"
    }
    spec = {
      validationFailureAction = "Enforce"
      background              = true
      rules = [
        {
          name = "inject-linkerd"
          match = {
            any = [{ resources = { kinds = ["Pod"], namespaces = ["online-boutique"] } }]
          }
          mutate = {
            patchStrategicMerge = {
              metadata = {
                annotations = {
                  "linkerd.io/inject" = "enabled"
                }
              }
            }
          }
        }
      ]
    }
  }
  depends_on = [helm_release.kyverno]
}

# Proactive Policy: Restrict Image Registries
resource "kubernetes_manifest" "policy_restrict_registries" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "restrict-image-registries"
    }
    spec = {
      validationFailureAction = "Audit"
      rules = [
        {
          name = "allow-trusted-registries"
          match = {
            any = [{ resources = { kinds = ["Pod"] } }]
          }
          validate = {
            message = "Only images from trusted registries are allowed."
            foreach = [
              {
                list       = "request.object.spec.containers"
                elementVar = "container"
                pattern = {
                  container = {
                    image = "docker.io/* | ghcr.io/* | registry.k8s.io/*"
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }
  depends_on = [helm_release.kyverno]
}
