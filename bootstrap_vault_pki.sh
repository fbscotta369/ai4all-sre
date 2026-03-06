#!/bin/bash
set -e

# 1. Enable PKI secrets engine
kubectl exec -n vault vault-0 -- vault secrets enable pki || echo "PKI already enabled"

# 2. Generate root CA
kubectl exec -n vault vault-0 -- vault write -field=certificate pki/root/generate/internal \
    common_name="linkerd.cluster.local" \
    ttl=87600h > /tmp/root_ca.crt || echo "CA already generated or error"

# 3. Configure URLs
kubectl exec -n vault vault-0 -- vault write pki/config/urls \
    issuing_certificates="http://vault.vault.svc:8200/v1/pki/ca" \
    crl_distribution_points="http://vault.vault.svc:8200/v1/pki/crl"

# 4. Create Role for Linkerd Mesh
kubectl exec -n vault vault-0 -- vault write pki/roles/mesh-role \
    allowed_domains="linkerd.cluster.local,identity.linkerd.cluster.local" \
    allow_subdomains=true \
    max_ttl=72h \
    allow_any_name=true \
    enforce_hostnames=false

# 5. Enable Kubernetes Auth
kubectl exec -n vault vault-0 -- vault auth enable kubernetes || echo "K8s auth already enabled"

# 6. Configure Kubernetes Auth
TOKEN_REVIEW_JWT=$(kubectl get secret -n cert-manager cert-manager-vault-token -o jsonpath='{.data.token}' | base64 -d)
K8S_CA_CERT=$(kubectl exec -n vault vault-0 -- cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
    token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
    kubernetes_host="https://kubernetes.default.svc" \
    kubernetes_ca_cert="$K8S_CA_CERT"

# 7. Create Policy for Cert-Manager
kubectl exec -n vault vault-0 -- vault policy write cert-manager-policy - <<'POLEOF'
path "pki/sign/mesh-role" {
  capabilities = ["update"]
}
POLEOF

# 8. Bind Policy to Cert-Manager ServiceAccount
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/cert-manager-role \
    bound_service_account_names=cert-manager-vault \
    bound_service_account_namespaces=cert-manager \
    policies=cert-manager-policy \
    ttl=24h

echo "Vault PKI Bootstrapped Successfully!"
