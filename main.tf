module "control_plane" {
  source = "./platforms/terraform/control-plane"
}

module "data_plane" {
  source = "./platforms/terraform/data-plane"

  argocd_namespace         = module.control_plane.argocd_namespace
  trivy_namespace          = module.control_plane.trivy_namespace
  keda_namespace           = module.control_plane.keda_namespace
  online_boutique_namespace = module.control_plane.online_boutique_namespace
  observability_namespace  = module.control_plane.observability_namespace

  depends_on = [module.control_plane]
}

module "governance" {
  source = "./platforms/terraform/governance"

  online_boutique_namespace = module.control_plane.online_boutique_namespace
  ai_lab_namespace          = module.control_plane.ai_lab_namespace
  ollama_namespace          = module.control_plane.ollama_namespace
  vault_namespace           = module.control_plane.vault_namespace
  alerting_namespace        = module.control_plane.alerting_namespace
  chaos_namespace           = module.control_plane.chaos_namespace
  observability_namespace   = module.control_plane.observability_namespace

  depends_on = [module.control_plane]
}
