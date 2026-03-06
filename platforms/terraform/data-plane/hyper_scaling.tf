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
        name = kubernetes_manifest.m2m_priority_level.manifest.metadata.name
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
                namespace = var.observability_namespace
              }
            }
          ]
        }
      ]
    }
  }
}

resource "null_resource" "wait_for_deployments" {
  provisioner "local-exec" {
    command = "echo 'Waiting for ArgoCD to sync deployments...' && sleep 20 && kubectl wait --for=condition=available deployment/productcatalogservice -n ${var.online_boutique_namespace} --timeout=300s || true"
  }
  depends_on = [kubernetes_manifest.argocd_app_boutique]
}

resource "kubernetes_manifest" "frontend_scaledobject" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "frontend-cpu-scaledobject"
      namespace = var.online_boutique_namespace
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
            query         = "sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{namespace='${var.online_boutique_namespace}', pod=~'frontend-.*'})"
            threshold     = "0.5" # Scale up if CPU usage > 0.5 cores
          }
        }
      ]
    }
  }
  depends_on = [helm_release.keda, null_resource.wait_for_deployments]
}

resource "kubernetes_manifest" "productcatalog_scaledobject" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "productcatalog-cpu-scaledobject"
      namespace = var.online_boutique_namespace
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = "productcatalogservice"
      }
      minReplicaCount = 2
      maxReplicaCount = 8
      triggers = [
        {
          type = "cpu"
          metadata = {
            value = "50" # 50% utilization
          }
        }
      ]
    }
  }
  depends_on = [helm_release.keda, null_resource.wait_for_deployments]
}
