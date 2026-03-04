resource "kubernetes_manifest" "m2m_priority_level" {
  manifest = {
    apiVersion = "flowcontrol.apiserver.k8s.io/v1"
    kind       = "PriorityLevelConfiguration"
    metadata = {
      name = "m2m-low-priority"
    }
    spec = {
      type = "Limited"
      limited = {
        nominalConcurrencyShares = 10
        limitResponse = {
          type = "Reject"
        }
      }
    }
  }
}

resource "kubernetes_manifest" "m2m_flow_schema" {
  manifest = {
    apiVersion = "flowcontrol.apiserver.k8s.io/v1"
    kind       = "FlowSchema"
    metadata = {
      name = "m2m-ai-agents"
    }
    spec = {
      priorityLevelConfiguration = {
        name = "m2m-low-priority"
      }
      matchingPrecedence = 500
      rules = [
        {
          resourceRules = [
            {
              apiGroups  = ["*"]
              resources  = ["*"]
              verbs      = ["*"]
              namespaces = ["*"]
            }
          ]
          subjects = [
            {
              kind = "ServiceAccount"
              serviceAccount = {
                name      = "ai-agent"
                namespace = "observability"
              }
            }
          ]
        }
      ]
    }
  }
}

# Tier-1 Hyper-Scaling: Proactive HPA via KEDA
resource "kubernetes_manifest" "frontend_scaledobject" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "frontend-cpu-scaledobject"
      namespace = "online-boutique"
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "argoproj.io/v1alpha1"
        kind       = "Rollout"
        name       = "frontend"
      }
      minReplicaCount = 3
      maxReplicaCount = 10
      triggers = [
        {
          type = "prometheus"
          metadata = {
            serverAddress = "http://kube-prometheus-prometheus.observability.svc.cluster.local:9090"
            metricName    = "frontend_cpu_usage"
            query         = "sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{namespace='online-boutique', pod=~'frontend-.*'})"
            threshold     = "0.5" # Scale up if CPU usage > 0.5 cores
          }
        }
      ]
    }
  }
  depends_on = [helm_release.keda]
}
