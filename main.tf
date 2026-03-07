# AI4ALL-SRE Root Orchestration
# Standardized entry point for the Multi-Cloud SRE Laboratory.

# By default, use the Local (Kind/Desktop) provider.
# Switch to ./platforms/terraform/providers/aws or ./gcp for cloud deployments.

module "platform" {
  source                      = "./platforms/terraform/providers/local"
  enable_kubernetes_manifests = var.enable_kubernetes_manifests
}

output "platform_status" {
  value = "SRE Kernel deployed on Local provider."
}
