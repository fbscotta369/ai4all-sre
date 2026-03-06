#!/bin/bash
# AI4ALL-SRE: Vault Configuration Script 🔐
set -e

VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

echo "Configuring Vault in pod: $VAULT_POD"

# 1. Enable KV Engine
kubectl exec -n vault $VAULT_POD -- vault secrets enable -path=secret kv-v2 || echo "KV already enabled"

# 2. Put Demo Secret
kubectl exec -n vault $VAULT_POD -- vault kv put secret/paymentservice api_key="vault-demo-token-123456789"

# 3. Enable Kubernetes Auth
kubectl exec -n vault $VAULT_POD -- vault auth enable kubernetes || echo "K8s auth already enabled"

# 4. Configure Kubernetes Auth
# Note: In Dev mode, Vault CA/token are often accessible locally
kubectl exec -n vault $VAULT_POD -- vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

# 5. Create Policy for Payment Service
kubectl exec -n vault $VAULT_POD -- /bin/sh -c "echo 'path \"secret/data/paymentservice\" { capabilities = [\"read\"] }' | vault policy write paymentservice-policy -"

# 6. Create Role for Payment Service
kubectl exec -n vault $VAULT_POD -- vault write auth/kubernetes/role/paymentservice-role \
    bound_service_account_names=paymentservice \
    bound_service_account_namespaces=online-boutique \
    policies=paymentservice-policy \
    ttl=24h

echo "✅ Vault configured with KV engine and Kubernetes authentication!"
