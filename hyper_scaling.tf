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
