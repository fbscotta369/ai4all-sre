# GCP Provider: Tier-1 GKE Bootstrapping

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 27.0"

  project_id = var.project_id
  name       = var.cluster_name
  region     = var.region

  network    = "default"
  subnetwork = "default"

  ip_range_pods     = ""
  ip_range_services = ""

  node_pools = [
    {
      name           = "sre-pool"
      machine_type   = "n2-standard-4"
      min_count      = 1
      max_count      = 3
      local_ssd_count = 0
      disk_size_gb   = 100
      disk_type      = "pd-standard"
      image_type     = "COS_CONTAINERD"
      auto_repair    = true
      auto_upgrade   = true
      preemptible    = false
      initial_node_count = 1
    },
  ]
}

variable "enable_kubernetes_manifests" {
  type    = bool
  default = true
}

module "sre_kernel" {
  source = "../../modules/sre-kernel"

  cluster_name = var.cluster_name
  environment  = var.environment

  enable_kubernetes_manifests = var.enable_kubernetes_manifests

  depends_on = [module.gke]
}
