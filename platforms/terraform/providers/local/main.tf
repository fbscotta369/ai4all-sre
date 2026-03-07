# Local Provider: Desktop/Kind Environment

# The Local provider assumes a K8s context already exists (e.g., Kind)
# It doesn't provision the cluster itself, but attaches the Kernel.

module "sre_kernel" {
  source = "../../modules/sre-kernel"

  cluster_name = "ai4all-sre-local"
  environment  = "development"
}
