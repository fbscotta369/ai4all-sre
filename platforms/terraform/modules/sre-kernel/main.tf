# SRE Kernel: Cloud-Agnostic Platform Core
# This module deploys the standard SRE stack once a K8s cluster is available.

variable "cluster_name" {
  type        = string
  description = "Name of the K8s cluster"
}

variable "environment" {
  type        = string
  default     = "production"
}

# The Kernel will eventually manage:
# - Namespaces
# - GitOps (ArgoCD)
# - Observability (Prom/Grafana/Loki)
# - Security (Kyverno/Linkerd)
# - AI/ML Components (Ollama/ChromaDB)
