#!/bin/bash
set -euo pipefail

# Dependency checks
require_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is required but not installed." >&2
        exit 1
    fi
}

require_command kubectl
require_command vault
require_command base64

# Dynamically detect Vault pod
VAULT_POD=$(kubectl get pods -n vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$VAULT_POD" ]; then
    echo "Error: Could not find Vault pod in namespace 'vault'" >&2
    exit 1
fi
echo "Using Vault pod: $VAULT_POD"

# Create secure temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

ROOT_CA_FILE="$TEMP_DIR/root_ca.crt"

# 1. Enable PKI secrets engine
kubectl exec -n vault "$VAULT_POD" -- vault secrets enable pki 2>/dev/null || echo "PKI already enabled"

# 2. Generate root CA
kubectl exec -n vault "$VAULT_POD" -- vault write -field=certificate pki/root/generate/internal \
    common_name="linkerd.cluster.local" \
    ttl=87600h > "$ROOT_CA_FILE" 2>/dev/null || echo "CA already generated or error"

# 3. Configure URLs
kubectl exec -n vault "$VAULT_POD" -- vault write pki/config/urls \
    issuing_certificates="http://vault.vault.svc:8200/v1/pki/ca" \
    crl_distribution_points="http://vault.vault.svc:8200/v1/pki/crl"

# 4. Create Role for Linkerd Mesh
kubectl exec -n vault "$VAULT_POD" -- vault write pki/roles/mesh-role \
    allowed_domains="linkerd.cluster.local,identity.linkerd.cluster.local" \
    allow_subdomains=true \
    max_ttl=72h \
    allow_any_name=true \
    enforce_hostnames=false

# 5. Enable Kubernetes Auth
kubectl exec -n vault "$VAULT_POD" -- vault auth enable kubernetes 2>/dev/null || echo "K8s auth already enabled"

# 6. Configure Kubernetes Auth
TOKEN_REVIEW_JWT=$(kubectl get secret -n cert-manager cert-manager-vault-token -o jsonpath='{.data.token}' | base64 -d)
K8S_CA_CERT=$(kubectl exec -n vault "$VAULT_POD" -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)

kubectl exec -n vault "$VAULT_POD" -- vault write auth/kubernetes/config \
    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
    kubernetes_host="https://kubernetes.default.svc" \
    kubernetes_ca_cert="$K8S_CA_CERT"

# 7. Create Policy for Cert-Manager
kubectl exec -n vault "$VAULT_POD" -- vault policy write cert-manager-policy - <<'POLEOF'
path "pki/sign/mesh-role" {
  capabilities = ["update"]
}
POLEOF

# 8. Bind Policy to Cert-Manager ServiceAccount
kubectl exec -n vault "$VAULT_POD" -- vault write auth/kubernetes/role/cert-manager-role \
    bound_service_account_names=cert-manager-vault \
    bound_service_account_namespaces=cert-manager \
    policies=cert-manager-policy \
    ttl=24h

echo "Vault PKI Bootstrapped Successfully!"
