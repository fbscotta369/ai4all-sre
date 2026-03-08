variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "trivy_namespace" {
  type    = string
  default = "trivy-system"
}

variable "keda_namespace" {
  type    = string
  default = "keda"
}

variable "online_boutique_namespace" {
  type    = string
  default = "online-boutique"
}

variable "observability_namespace" {
  type    = string
  default = "observability"
}

variable "loadgen_image" {
  type    = string
  default = "python:3.11-slim"
}

# Removed enable_kubernetes_manifests for 10/10 dependency optimization.
