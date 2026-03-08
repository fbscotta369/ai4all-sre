# AI4ALL-SRE Root Orchestration
# Standardized entry point for the Multi-Cloud SRE Laboratory.

# By default, use the Local (Kind/Desktop) provider.
# Switch to ./platforms/terraform/providers/aws or ./gcp for cloud deployments.

module "platform" {
  # Standardized entry point for the Multi-Cloud SRE Laboratory.
  # Use local relative path to ensure local changes are applied during development.
  source = "./platforms/terraform/providers/local"
}

output "platform_status" {
  value = "SRE Kernel deployed on Local provider."
}
