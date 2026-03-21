#!/bin/bash
set -euo pipefail

echo "------------------------------------------------"
echo "🚀 Provisioning AI Agent Hybrid Components..."
echo "------------------------------------------------"

# Generate secure random passwords if not provided via environment variables
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=' | head -c "$length"
}

# MinIO credentials
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-admin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-$(generate_password 32)}"

# Grafana admin credentials
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-$(generate_password 24)}"

# Redis URL (default to local service)
REDIS_URL="${REDIS_URL:-redis://redis.observability.svc.cluster.local:6379}"

# 1. Ensure Namespace exists
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# 2. Create AI Agent Credentials Secret
echo "Creating ai-agent-credentials secret..."
kubectl create secret generic ai-agent-credentials \
  -n observability \
  --from-literal=redis_url="${REDIS_URL}" \
  --from-literal=minio_access_key="${MINIO_ACCESS_KEY}" \
  --from-literal=minio_secret_key="${MINIO_SECRET_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Create Grafana Admin Secret
echo "Creating grafana-admin secret..."
kubectl create secret generic grafana-admin \
  -n observability \
  --from-literal=admin-user="${GRAFANA_ADMIN_USER}" \
  --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Provision Redis Deployment (Direct Manifest)
echo "Deploying Redis for debounce..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: observability
  labels:
    app: redis
    component: sre-agent-debounce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7.2-alpine
        ports:
        - containerPort: 6379
        resources:
          limits:
            cpu: 200m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: observability
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
EOF

echo "✅ Hybrid components provisioned."
