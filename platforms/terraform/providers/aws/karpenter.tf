# Karpenter — Enterprise-grade dynamic node provisioning
# Enables the AI Agent to scale hardware (EC2) rather than just pods.

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  namespace  = "kube-system"
  version    = "v1.1.0" # Latest stable for NodePools

  set {
    name  = "settings.aws.clusterName"
    value = "ai4all-sre-cluster"
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = "KarpenterNodeInstanceProfile-ai4all-sre"
  }
}

# NodePool — Defines the fleet of machines the AI can "order"
resource "kubernetes_manifest" "karpenter_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "sre-laboratory-fleet"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand", "spot"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["c6i", "m6i", "r6i"] },
          ]
          nodeClassRef = {
            name = "default"
          }
        }
      }
      limits = {
        cpu = 1000
      }
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        expireAfter         = "720h"
      }
    }
  }
  depends_on = [helm_release.karpenter]
}

# EC2NodeClass — Defines the AWS-specific configuration
resource "kubernetes_manifest" "karpenter_nodeclass" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2"
      role      = "KarpenterNodeRole-ai4all-sre"
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = "ai4all-sre-cluster" } }
      ]
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = "ai4all-sre-cluster" } }
      ]
    }
  }
  depends_on = [helm_release.karpenter]
}
