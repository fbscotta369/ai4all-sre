#!/bin/bash
set -e

VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

echo "Bootstrapping Vault PKI in pod: $VAULT_POD"

# 1. Enable PKI secrets engine
kubectl exec -n vault $VAULT_POD -- vault secrets enable pki || echo "PKI already enabled"
kubectl exec -n vault $VAULT_POD -- vault secrets tune -max-lease-ttl=87600h pki

# 2. Generate Root CA
mkdir -p .certs
kubectl exec -n vault $VAULT_POD -- vault write -field=certificate pki/root/generate/internal     common_name="ai4all.sre.cluster.local"     ttl=87600h > .certs/root-ca.crt

# 3. Configure URLs
kubectl exec -n vault $VAULT_POD -- vault write pki/config/urls     issuing_certificates="http://vault.vault.svc:8200/v1/pki/ca"     crl_distribution_points="http://vault.vault.svc:8200/v1/pki/crl"

# 4. Create Role for Cert-Manager
kubectl exec -n vault $VAULT_POD -- vault write pki/roles/mesh-role     allowed_domains="linkerd.online-boutique, identity.linkerd.cluster.local"     allow_subdomains=true     max_ttl=72h

# 5. Policy for Cert-Manager to sign certs
kubectl exec -n vault $VAULT_POD -- /bin/sh -c "echo 'path \"pki/sign/mesh-role\" { capabilities = [\"create\", \"update\"] }' | vault policy write cert-manager-policy -"

# 6. Bind Cert-Manager SA to Policy
kubectl exec -n vault $VAULT_POD -- vault write auth/kubernetes/role/cert-manager-role     bound_service_account_names=cert-manager     bound_service_account_namespaces=cert-manager     policies=cert-manager-policy     ttl=24h

echo "✅ Vault PKI and Cert-Manager integration configured!"
