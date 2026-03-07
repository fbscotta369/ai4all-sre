# Local Provider: Desktop/Kind Environment

# The Local provider assumes a K8s context already exists (e.g., Kind)
# It doesn't provision the cluster itself, but attaches the Kernel.

variable "enable_kubernetes_manifests" {
  type    = bool
  default = true
}

module "sre_kernel" {
  source = "../../modules/sre-kernel"

  cluster_name = "ai4all-sre-local"
  environment  = "development"

  enable_kubernetes_manifests = var.enable_kubernetes_manifests

  # Namespaces from module defaults or configured here
  argocd_namespace          = "argocd"
  trivy_namespace           = "trivy-system"
  keda_namespace            = "keda"
  online_boutique_namespace = "online-boutique"
  observability_namespace   = "observability"
  loadgen_image             = "python:3.11-slim"
}
