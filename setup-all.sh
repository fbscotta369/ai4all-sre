#!/bin/bash

# AI4ALL-SRE Master Setup Script 🚀
set -e

echo "Starting AI4ALL-SRE Laboratory Setup..."
echo "------------------------------------------------"

# 1. Prerequisites Doctor 🩺
# This function checks for a command and provides installation help if missing.
doctor_check() {
    local cmd=$1
    local install_cmd=$2
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd is not installed."
        echo "------------------------------------------------"
        echo "💡 How to fix (Kubuntu/Debian/Ubuntu):"
        echo "   sudo bash -c \"$install_cmd\""
        echo "------------------------------------------------"
        
        # Proactively offer to run the command if in an interactive terminal
        if [ -t 0 ]; then
            read -p "Would you like me to try installing $cmd for you? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo bash -c "$install_cmd"
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
    echo "✅ $cmd is installed."
}

doctor_check "kubectl" "apt-get update && apt-get install -y apt-transport-https ca-certificates curl && mkdir -p /etc/apt/keyrings && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && apt-get update && apt-get install -y kubectl"
doctor_check "terraform" "wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | tee /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y terraform"
doctor_check "helm" "curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null && echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main\" | tee /etc/apt/sources.list.d/helm-stable-debian.list && apt-get update && apt-get install -y helm"
doctor_check "docker" "apt-get update && apt-get install -y docker.io"

# 2. k9s Installation (Optional but highly recommended)
if ! command -v k9s &> /dev/null; then
    echo "⚠️ k9s is not installed. Installing k9s for cluster observability..."
    curl -sS https://webi.sh/k9s | sh
    source ~/.config/envman/PATH.env || true
    echo "✅ k9s installed successfully."
else
    echo "✅ k9s is installed."
fi


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

# 5. Terraform Apply (Two-Stage to resolve CRD dependencies)
echo "Applying Base Helm Charts (CRDs)..."
terraform apply -target=helm_release.chaos_mesh -target=helm_release.kyverno -target=helm_release.argo_rollouts -auto-approve

echo "Applying full Infrastructure..."
terraform apply -auto-approve

echo "------------------------------------------------"
echo "⏳ Waiting for core dashboard endpoints to become ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/kube-prometheus-grafana -n observability --timeout=300s
kubectl rollout status deployment/goalert -n incident-management --timeout=300s
kubectl rollout status deployment/frontend -n online-boutique --timeout=300s
kubectl rollout status deployment/chaos-dashboard -n chaos-testing --timeout=300s

echo "------------------------------------------------"
echo "✅ Autonomous Laboratory Setup Complete!"
echo "------------------------------------------------"
echo "The Multi-Agent System (Director, Network, DB, Compute) is already running in the cluster."
echo "You can view its logs via:"
echo "  kubectl logs -f deployment/ai-agent -n observability"
echo "------------------------------------------------"
echo "🚀 Automatically launching dashboards..."
exec ./start-dashboards.sh
