#!/bin/bash

# AI4ALL-SRE Master Setup Script 🚀
set -e

echo "Starting AI4ALL-SRE Laboratory Setup..."
echo "------------------------------------------------"

# 1. Dependency Checks
check_dep() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ Error: $1 is not installed."
        exit 1
    fi
    echo "✅ $1 is installed."
}

check_dep "kubectl"
check_dep "terraform"
check_dep "helm"
check_dep "docker"

# 3. K3s / Kubernetes Context Check
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster."
    echo "💡 Recommendation: If using a local environment, start minikube or k3d first."
    exit 1
fi
echo "✅ Kubernetes cluster is reachable."

# 3.5 Storage Class Verification
if ! kubectl get sc | grep -q "(default)\|default"; then
    echo "⚠️ Warning: No default StorageClass found. Loki and Prometheus PVCs might hang."
    echo "💡 Ensure your cluster (k3s/minikube/kind) has a default local provisioner."
else
    echo "✅ Default StorageClass exists for Persistent Volumes."
fi

# 3.8 Linkerd Certificate Generation
if [ ! -f "issuer.crt" ] || [ ! -f "issuer.key" ] || [ ! -f "trust-anchor.crt" ]; then
    echo "⚠️ Linkerd mTLS certificates not found. Generating them via Python cryptography..."
    
    python3 generate_certs.py
    
    # Fix permissions if needed
    chmod 600 issuer.key trust-anchor.key 2>/dev/null || true
    echo "✅ Linkerd certificates generated successfully."
else
    echo "✅ Linkerd certificates found."
fi

# 4. Terraform Initialization
echo "------------------------------------------------"
echo "Initializing Terraform..."
terraform init

# 5. Terraform Apply
echo "Applying Infrastructure..."
terraform apply -auto-approve

echo "------------------------------------------------"
echo "✅ Autonomous Laboratory Setup Complete!"
echo "------------------------------------------------"
echo "To access the centralized SRE dashboards, run:"
echo "  ./start-dashboards.sh"
echo ""
echo "The Multi-Agent System (Director, Network, DB, Compute) is already running in the cluster."
echo "You can view its logs via:"
echo "  kubectl logs -f deployment/ai-agent -n observability"
echo "------------------------------------------------"
