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

variable "ai_agent_image" {
  type        = string
  default     = "ai4all-sre/ai-agent:latest"
  description = "Container image for the AI agent. Build with `docker build -t ai4all-sre/ai-agent:latest -f components/ai-agent/Dockerfile.agent .`"
}

variable "vault_namespace" {
  type    = string
  default = "vault"
}

variable "ollama_namespace" {
  type    = string
  default = "ollama"
}

variable "alerting_namespace" {
  type    = string
  default = "incident-management"
}

variable "chaos_namespace" {
  type    = string
  default = "chaos-testing"
}

variable "slack_token" {
  type        = string
  description = "Slack Bot User OAuth Token"
  default     = "xoxb-mock-token-for-lab-environment"
}

variable "slack_client_id" {
  type        = string
  description = "Slack Client ID"
  default     = "mock-client-id"
}

variable "slack_client_secret" {
  type        = string
  description = "Slack Client Secret"
  default     = "mock-client-secret"
}

variable "slack_signing_secret" {
  type        = string
  description = "Slack Signing Secret"
  default     = "mock-signing-secret"
}

# Removed enable_kubernetes_manifests for 10/10 dependency optimization.
