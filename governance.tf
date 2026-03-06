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
                    "ollama",
                    "cert-manager"
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
          exclude = {
            any = [
              { resources = { namespaces = ["kube-system", "linkerd", "cert-manager", "vpa", "minio"] } }
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
        any = [
          { resources = { namespaces = ["kube-system", "linkerd", "cert-manager", "vpa", "minio"] } }
        ]
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
          exclude = {
            any = [
              { resources = { namespaces = ["kube-system", "linkerd", "cert-manager", "vpa", "minio"] } }
            ]
          }
          validate = {
            message = "Only images from trusted registries are allowed."
            foreach = [
              {
                list       = "request.object.spec.containers"
                elementVar = "container"
                pattern = {
                  container = {
                    image = "docker.io/* | ghcr.io/* | registry.k8s.io/* | *.pkg.dev/* | gcr.io/* | quay.io/*"
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

# FIX 4: Block images with CRITICAL vulnerabilities
# Uses Trivy Operator's admission controller integration.
# Trivy Operator must be running with --scannerReportTTL and admission scanning enabled.
#
# Activation: helm upgrade trivy-operator trivy-operator/trivy-operator \
#   --set="operator.scanJobsInSameNamespace=true" \
#   --set="admissionController.enabled=true"
#
# The policy below audits all new pods. When Trivy Operator's admission webhook
# is enabled, it performs the actual scan; this policy provides the policy guard.
resource "kubernetes_manifest" "policy_block_critical_vulnerabilities" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "block-critical-vulnerabilities"
      annotations = {
        "policies.kyverno.io/title"       = "Block Critical CVEs via Trivy"
        "policies.kyverno.io/description" = "Blocks Pod admission when the image has a CRITICAL vulnerability detected by Trivy Operator."
      }
    }
    spec = {
      # Changed from Enforce to Audit until Trivy Operator admission controller is validated.
      # Switch to Enforce once `trivy-operator admissionwebhook` is stable in your cluster.
      validationFailureAction = "Audit"
      background              = false  # Only evaluate on admission, not background
      rules = [
        {
          name = "check-vulnerability-report"
          match = {
            any = [{ resources = { kinds = ["Pod"] } }]
          }
          exclude = {
            any = [{ resources = { namespaces = ["kube-system", "kyverno", "observability", "trivy-system", "linkerd", "argocd", "argo-rollouts", "incident-management", "chaos-testing", "ollama", "default", "cert-manager", "vpa", "minio"] } }, { resources = { names = ["behavioral-loadgen"] } }]
          }
          preconditions = {
            all = [
              {
                key      = "{{ request.operation }}"
                operator = "AnyIn"
                value    = ["CREATE", "UPDATE"]
              }
            ]
          }
          validate = {
            message = "Image '{{ element.image }}' has CRITICAL vulnerabilities. See: kubectl get vulnerabilityreports -n {{ request.object.metadata.namespace }}"
            foreach = [
              {
                list       = "request.object.spec.containers"
                elementVar = "element"
                # Look up VulnerabilityReport for this image in the target namespace.
                # Trivy Operator names reports after the owning ReplicaSet.
                context = [
                  {
                    name = "vulnReport"
                    apiCall = {
                      urlPath = "/apis/aquasecurity.github.io/v1alpha1/namespaces/{{ request.object.metadata.namespace }}/vulnerabilityreports"
                      jmesPath = "items[?report.artifact.tag == '{{ element.image }}'].report.summary.criticalCount | [0]"
                    }
                  }
                ]
                deny = {
                  conditions = {
                    all = [
                      {
                        key      = "{{ vulnReport }}"
                        operator = "GreaterThan"
                        value    = "0"
                      }
                    ]
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }
  depends_on = [helm_release.kyverno, helm_release.trivy]
}
