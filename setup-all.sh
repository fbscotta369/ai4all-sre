#!/bin/bash

# AI4ALL-SRE Master Setup Script 🚀
set -e

echo "Starting AI4ALL-SRE Laboratory Setup..."
echo "------------------------------------------------"

# 0. Environment Bootstrap 🌐
# Ensure local bin is in PATH for webi installs (k9s, etc.)
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.config/envman/PATH.env" ] && source "$HOME/.config/envman/PATH.env"

# 1. Prerequisites Doctor 🩺
# This function checks for a command and provides installation help if missing.
doctor_check() {
    local cmd=$1
    local install_cmd=$2
    local use_sudo=${3:-true}

    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd is not installed."
        echo "------------------------------------------------"
        echo "💡 How to fix (Kubuntu/Debian/Ubuntu):"
        if [ "$use_sudo" = true ]; then
            echo "   sudo bash -c \"$install_cmd\""
        else
            echo "   $install_cmd"
        fi
        echo "------------------------------------------------"
        
        # Proactively offer to run the command if in an interactive terminal
        if [ -t 0 ]; then
            read -p "Would you like me to try installing $cmd for you? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Implement up to 3 retries for transient network errors
                for i in {1..3}; do
                    echo "[*] Attempt $i: Installing $cmd..."
                    local run_cmd
                    if [ "$use_sudo" = true ]; then
                        run_cmd="sudo bash -c \"$install_cmd\""
                    else
                        run_cmd="$install_cmd"
                    fi

                    if eval "$run_cmd"; then
                        echo "✅ $cmd installed successfully."
                        # Re-source PATH if we just installed k9s/webi tools
                        [ -f "$HOME/.config/envman/PATH.env" ] && source "$HOME/.config/envman/PATH.env"
                        return 0
                    fi
                    echo "⚠️ Attempt $i failed. Retrying in 5 seconds..."
                    sleep 5
                done
                echo "❌ Failed to install $cmd after 3 attempts."
                exit 1
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
    echo "✅ $cmd is installed."
}

# Check for running services
docker_daemon_check() {
    if ! sudo docker info &> /dev/null; then
        echo "❌ Error: Docker daemon is not running or current user has no permissions."
        echo "------------------------------------------------"
        echo "💡 How to fix:"
        echo "   sudo systemctl start docker"
        echo "   sudo usermod -aG docker $USER (then logout/login)"
        echo "------------------------------------------------"
        exit 1
    fi
    echo "✅ Docker daemon is running."
}

doctor_check "kubectl" "apt-get update --fix-missing && apt-get install -y apt-transport-https ca-certificates curl && mkdir -p /etc/apt/keyrings && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && apt-get update && apt-get install -y kubectl"
doctor_check "terraform" "apt-get update --fix-missing && wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | tee /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y terraform"
doctor_check "helm" "apt-get update --fix-missing && curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null && echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main\" | tee /etc/apt/sources.list.d/helm-stable-debian.list && apt-get update && apt-get install -y helm"
doctor_check "docker" "apt-get update --fix-missing && apt-get install -y docker.io"
doctor_check "k9s" "curl -sS https://webi.sh/k9s | sh" false

docker_daemon_check


# 1.5 Cluster Doctor 🏥
# This function ensures a reachable Kubernetes cluster exists, or offers to bootstrap K3s.
cluster_doctor() {
    echo "Checking Kubernetes cluster connectivity..."
    
    # Try reachable cluster
    if kubectl cluster-info &> /dev/null; then
        echo "✅ Kubernetes cluster is reachable."
        return 0
    fi

    echo "❌ Error: Cannot connect to any Kubernetes cluster."
    echo "------------------------------------------------"
    echo "💡 Local Cluster Bootstrapping (K3s):"
    
    if [ -t 0 ]; then
        read -p "Would you like me to install and start a local K3s cluster for you? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Bootstrapping K3s (this may require sudo password)..."
            curl -sfL https://get.k3s.io | sh -
            
            echo "[*] Configuring Kubeconfig permissions..."
            mkdir -p ~/.kube
            sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
            sudo chown $USER:$USER ~/.kube/config
            chmod 600 ~/.kube/config
            
            echo "[*] Waiting for K3s to initialize..."
            sleep 10
            
            if kubectl cluster-info &> /dev/null; then
                echo "✅ K3s cluster bootstrapped and reachable."
                return 0
            else
                echo "❌ K3s started but kubectl still cannot connect. Please check 'journalctl -u k3s'."
                exit 1
            fi
        else
            echo "💡 Recommendation: Start minikube, kind, or k3d manually to proceed."
            exit 1
        fi
    else
        echo "❌ Non-interactive terminal. Please start a cluster manually."
        exit 1
    fi
}

# 1.8 Gateway API Doctor (K3s/Traefik Conflict Resolver) 🌐
# K3s installs Traefik with Gateway API CRDs. Linkerd needs to 'adopt' them.
adopt_gateway_crds() {
    echo "Checking for Gateway API CRD conflicts (Traefik vs Linkerd)..."
    local crds=(
        "gatewayclasses.gateway.networking.k8s.io"
        "gateways.gateway.networking.k8s.io"
        "httproutes.gateway.networking.k8s.io"
        "referencegrants.gateway.networking.k8s.io"
        "backlayerregulations.gateway.networking.k8s.io"
    )

    for crd in "${crds[@]}"; do
        if kubectl get crd "$crd" &> /dev/null; then
            echo "[*] Patching $crd for Linkerd adoption..."
            kubectl annotate crd "$crd" meta.helm.sh/release-name=linkerd-crds --overwrite
            kubectl annotate crd "$crd" meta.helm.sh/release-namespace=linkerd --overwrite
            kubectl label crd "$crd" app.kubernetes.io/managed-by=Helm --overwrite
        fi
    done
    echo "✅ Gateway API CRDs prepared for Linkerd."
}
# 1.9 Kernel Doctor (Inotify Restorer) 🧠
# Resolves 'to create fsnotify watcher: too many open files' in high-concurrency labs.
kernel_doctor() {
    echo "Checking kernel inotify limits..."
    local cur_instances=$(sysctl -n fs.inotify.max_user_instances)
    local cur_watches=$(sysctl -n fs.inotify.max_user_watches)
    local target_instances=512
    local target_watches=128000

    if [ "$cur_instances" -lt "$target_instances" ] || [ "$cur_watches" -lt "$target_watches" ]; then
        echo "⚠️ Warning: Kernel inotify limits are too low for high-fidelity observability."
        echo "   Current: Instances=$cur_instances, Watches=$cur_watches"
        echo "   Target:  Instances=$target_instances, Watches=$target_watches"
        echo "------------------------------------------------"
        
        if [ -t 0 ]; then
            read -p "Would you like me to optimize these kernel limits for you? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "[*] Applying kernel optimizations..."
                sudo bash -c "echo fs.inotify.max_user_instances=$target_instances >> /etc/sysctl.conf"
                sudo bash -c "echo fs.inotify.max_user_watches=$target_watches >> /etc/sysctl.conf"
                sudo sysctl -p
                echo "✅ Kernel limits optimized and applied."
            else
                echo "💡 Note: You may encounter 'fsnotify' errors in sidecars/loki."
            fi
        fi
    else
        echo "✅ Kernel inotify limits are optimized ($cur_instances/$cur_watches)."
    fi
}

# Run the Doctors
doctor_check "kubectl" "apt-get update --fix-missing && apt-get install -y apt-transport-https ca-certificates curl && mkdir -p /etc/apt/keyrings && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && apt-get update && apt-get install -y kubectl"
doctor_check "terraform" "apt-get update --fix-missing && wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | tee /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y terraform"
doctor_check "helm" "apt-get update --fix-missing && curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null && echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main\" | tee /etc/apt/sources.list.d/helm-stable-debian.list && apt-get update && apt-get install -y helm"
doctor_check "docker" "apt-get update --fix-missing && apt-get install -y docker.io"

docker_daemon_check
cluster_doctor
adopt_gateway_crds
kernel_doctor

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

# 5. Terraform Apply (Multi-Stage to resolve CRD dependencies)
echo "Applying Base Helm Charts (CRDs & Controllers)..."
terraform apply -target=helm_release.chaos_mesh -target=helm_release.kyverno -target=helm_release.argo_rollouts -target=helm_release.argocd -target=helm_release.kube_prometheus_stack -auto-approve

echo "------------------------------------------------"
echo "⏳ Waiting for CRDs to register in the Kubernetes API..."
sleep 20

echo "Applying full Infrastructure..."
terraform apply -auto-approve

echo "------------------------------------------------"
echo "⏳ Waiting for core dashboard endpoints and GitOps sync..."
# Wait for ArgoCD app to be healthy (GitOps sync)
# We use || true here because sometimes ArgoCD reporting is slightly delayed even when pods are running
kubectl wait --for=jsonpath='{.status.health.status}'=Healthy application/ai4all-sre -n argocd --timeout=300s || echo "⚠️ Warning: ArgoCD app sync is taking longer than expected."

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/kube-prometheus-grafana -n observability --timeout=300s
kubectl rollout status deployment/goalert -n incident-management --timeout=300s

# Wait for Argo Rollout instead of Deployment for the frontend
if kubectl get rollout frontend -n online-boutique &> /dev/null; then
    echo "Checking Argo Rollout status for frontend..."
    kubectl get rollout frontend -n online-boutique -o jsonpath='{"Status: "}{.status.phase}{"\n"}'
else
    echo "⚠️ Warning: frontend Rollout not found yet."
fi

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
