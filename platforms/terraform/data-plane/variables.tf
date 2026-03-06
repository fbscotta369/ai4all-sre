variable "argocd_namespace" { type = string }
variable "trivy_namespace" { type = string }
variable "keda_namespace" { type = string }
variable "online_boutique_namespace" { type = string }
variable "observability_namespace" { type = string }
variable "loadgen_image" {
  type    = string
  default = "python:3.11-slim"
}
