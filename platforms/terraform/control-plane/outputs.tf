output "linkerd_namespace" {
  value = kubernetes_namespace.linkerd.metadata[0].name
}

output "minio_namespace" {
  value = kubernetes_namespace.minio.metadata[0].name
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "trivy_namespace" {
  value = kubernetes_namespace.trivy.metadata[0].name
}

output "keda_namespace" {
  value = kubernetes_namespace.keda.metadata[0].name
}

output "online_boutique_namespace" {
  value = kubernetes_namespace.online_boutique.metadata[0].name
}

output "ai_lab_namespace" {
  value = kubernetes_namespace.ai_lab.metadata[0].name
}

output "ollama_namespace" {
  value = kubernetes_namespace.ollama.metadata[0].name
}

output "vault_namespace" {
  value = kubernetes_namespace.vault.metadata[0].name
}

output "alerting_namespace" {
  value = kubernetes_namespace.alerting.metadata[0].name
}

output "chaos_namespace" {
  value = kubernetes_namespace.chaos.metadata[0].name
}

output "observability_namespace" {
  value = kubernetes_namespace.observability.metadata[0].name
}
