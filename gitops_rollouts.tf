resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = "argo-rollouts"
  create_namespace = true
  version    = "2.35.1"
}

# Note: We will transform the frontend deployment in a later step 
# to ensure the controller is healthy first.
