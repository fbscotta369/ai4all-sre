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

variable "enable_kubernetes_manifests" {
  description = "Toggle for kubernetes_manifest resources to avoid GVK errors during bootstrap."
  type        = bool
  default     = true
}
