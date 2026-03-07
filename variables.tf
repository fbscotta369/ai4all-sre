variable "loadgen_image" {
  description = "Container image for the behavioral load generator. Build with Dockerfile.loadgen."
  type        = string
  default     = "python:3.11-slim"
  # TODO: Update this to a pinned registry image once CI builds are configured:
  # default = "ghcr.io/ai4all-sre/loadgen:1.0.0@sha256:<digest>"
}

variable "enable_kubernetes_manifests" {
  description = "Toggle for kubernetes_manifest resources to avoid GVK errors during bootstrap."
  type        = bool
  default     = true
}
