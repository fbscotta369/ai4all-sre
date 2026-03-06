
# FinOps Governance: Resource Quotas for Online Boutique
resource "kubernetes_resource_quota" "online_boutique_quota" {
  metadata {
    name      = "online-boutique-quota"
    namespace = var.online_boutique_namespace
  }
  spec {
    hard = {
      cpu    = "10"
      memory = "16Gi"
      pods   = "50"
    }
  }
}

resource "kubernetes_limit_range" "online_boutique_limits" {
  metadata {
    name      = "online-boutique-limits"
    namespace = var.online_boutique_namespace
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "64Mi"
      }
    }
  }
}

# FinOps Governance: Resource Quotas for AI Lab
resource "kubernetes_resource_quota" "ai_lab_quota" {
  metadata {
    name      = "ai-lab-quota"
    namespace = var.ai_lab_namespace
  }
  spec {
    hard = {
      cpu    = "16"
      memory = "32Gi"
      pods   = "20"
    }
  }
}
