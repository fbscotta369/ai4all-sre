#!/bin/bash
set -e

echo "------------------------------------------------"
echo "🚀 Provisioning AI Agent Hybrid Components..."
echo "------------------------------------------------"

# 1. Ensure Namespace exists
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -

# 2. Create AI Agent Credentials Secret
echo "Creating ai-agent-credentials secret..."
kubectl create secret generic ai-agent-credentials \
  -n observability \
  --from-literal=redis_url="redis://redis.observability.svc.cluster.local:6379" \
  --from-literal=minio_access_key="admin" \
  --from-literal=minio_secret_key="password123!" \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Create Grafana Admin Secret
echo "Creating grafana-admin secret..."
kubectl create secret generic grafana-admin \
  -n observability \
  --from-literal=admin-user="admin" \
  --from-literal=admin-password="admin" \
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
