#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Vault Secret Seed Script
# Seeds all platform secrets into Vault KV v2 engine (dev mode).
# This script runs as a Kubernetes Job after Vault is deployed.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://vault.vault.svc.cluster.local:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"

echo "═══════════════════════════════════════════════════════════"
echo "  Vault Secret Seeder — AI4ALL SRE Platform"
echo "  Vault: ${VAULT_ADDR}"
echo "═══════════════════════════════════════════════════════════"

# Wait for Vault to be ready
echo "⏳ Waiting for Vault to be ready..."
until vault status -address="${VAULT_ADDR}" 2>/dev/null | grep -q "Sealed.*false"; do
  sleep 2
done
echo "✅ Vault is unsealed and ready."

export VAULT_ADDR VAULT_TOKEN

# Enable KV v2 engine (idempotent — ignore if already enabled)
vault secrets enable -version=2 -path=secret kv 2>/dev/null || true

echo ""
echo "── Seeding MinIO Credentials ──"
vault kv put secret/minio/credentials \
  root_user="admin" \
  root_password="password123!" \
  access_key="admin" \
  secret_key="password123!"

echo "── Seeding GoAlert/PostgreSQL Credentials ──"
vault kv put secret/goalert/database \
  postgres_password="goalertpass" \
  connection_url="postgres://postgres:goalertpass@goalert-db-postgresql.incident-management.svc.cluster.local:5432/postgres?sslmode=disable"

echo "── Seeding Grafana Credentials ──"
vault kv put secret/grafana/admin \
  password="admin123"

echo "── Seeding Redis Configuration ──"
vault kv put secret/redis/connection \
  url="redis://redis.observability.svc.cluster.local:6379/0"

echo ""
echo "── Configuring Kubernetes Auth Method ──"
vault auth enable kubernetes 2>/dev/null || true
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

echo ""
echo "── Creating Vault Policies ──"

# Policy: MinIO read-only
vault policy write minio-readonly - <<'POLICY'
path "secret/data/minio/credentials" {
  capabilities = ["read"]
}
POLICY

# Policy: GoAlert read-only
vault policy write goalert-readonly - <<'POLICY'
path "secret/data/goalert/database" {
  capabilities = ["read"]
}
POLICY

# Policy: Grafana read-only
vault policy write grafana-readonly - <<'POLICY'
path "secret/data/grafana/admin" {
  capabilities = ["read"]
}
POLICY

# Policy: AI Agent full read
vault policy write ai-agent-readonly - <<'POLICY'
path "secret/data/minio/credentials" {
  capabilities = ["read"]
}
path "secret/data/redis/connection" {
  capabilities = ["read"]
}
POLICY

echo ""
echo "── Creating Kubernetes Auth Roles ──"

# Role: MinIO (control-plane namespace)
vault write auth/kubernetes/role/minio \
  bound_service_account_names="*" \
  bound_service_account_namespaces="minio" \
  policies="minio-readonly" \
  ttl="1h"

# Role: GoAlert (incident-management namespace)
vault write auth/kubernetes/role/goalert \
  bound_service_account_names="*" \
  bound_service_account_namespaces="incident-management" \
  policies="goalert-readonly" \
  ttl="1h"

# Role: Observability (ai-agent, grafana)
vault write auth/kubernetes/role/observability \
  bound_service_account_names="ai-agent" \
  bound_service_account_namespaces="observability" \
  policies="ai-agent-readonly,grafana-readonly" \
  ttl="1h"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Vault secret seeding complete!"
echo "  Secrets stored at: secret/minio, secret/goalert,"
echo "                     secret/grafana, secret/redis"
echo "  Kubernetes Auth: 3 roles configured"
echo "═══════════════════════════════════════════════════════════"
