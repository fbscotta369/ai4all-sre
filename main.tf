# AI4ALL-SRE Root Orchestration
# Standardized entry point for the Multi-Cloud SRE Laboratory.

# By default, use the Local (Kind/Desktop) provider.
# Switch to ./platforms/terraform/providers/aws or ./gcp for cloud deployments.

module "platform" {
  # Fortune 500 Standard: Source modules from versioned Git tags to prevent breaking changes.
  source                      = "git::https://github.com/fbscotta369/ai4all-sre.git//platforms/terraform/providers/local?ref=v1.0.0"
}

output "platform_status" {
  value = "SRE Kernel deployed on Local provider."
}
