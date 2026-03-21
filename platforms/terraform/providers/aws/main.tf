# AWS Provider: Tier-1 EKS Bootstrapping

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    sre_nodes = {
      min_size       = 2
      max_size       = 5
      desired_size   = 2
      instance_types = ["t3.large"]
    }
  }
}

variable "enable_kubernetes_manifests" {
  type    = bool
  default = true
}

# Call the SRE Kernel once the cluster is ready
module "sre_kernel" {
  source = "../../modules/sre-kernel"

  cluster_name = var.cluster_name
  environment  = var.environment

  enable_kubernetes_manifests = var.enable_kubernetes_manifests

  depends_on = [module.eks]
}
