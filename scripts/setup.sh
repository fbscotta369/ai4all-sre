#!/bin/bash

# AI4ALL-SRE Master Setup Script 🚀
set -e

echo "Starting AI4ALL-SRE Laboratory Setup..."
echo "------------------------------------------------"

# 0. Environment Bootstrap 🌐
# Parse global flags
NON_INTERACTIVE=false
for arg in "$@"; do
    if [ "$arg" == "--non-interactive" ]; then
        NON_INTERACTIVE=true
        break
    fi
done

# OS Detection 🕵️
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
    Linux*)
        OS=linux
        if command -v lsb_release &> /dev/null; then
            OS_ID=$(lsb_release -is)
            OS_VERSION=$(lsb_release -rs)
            OS_NAME=$(lsb_release -ds)
        elif [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_ID=$ID
            OS_VERSION=$VERSION_ID
            OS_NAME=$PRETTY_NAME
        fi
        ;;
    Darwin*)
        OS=macos
        OS_ID="macOS"
        OS_VERSION=$(sw_vers -productVersion)
        OS_NAME="macOS $OS_VERSION"
        ;;
    *)
        OS=unknown
        OS_ID="Unknown"
        OS_VERSION="Unknown"
        OS_NAME="Unknown OS"
        ;;
esac

echo "Detected Environment: $OS_NAME ($OS_ID $OS_VERSION)"
echo "------------------------------------------------"

# Safe Sed Helper (macOS vs Linux)
safe_sed() {
    if [ "$OS" = "macos" ]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Package Manager Abstractor
pkg_install() {
    local pkgs=("$@")
    if [ "$OS" = "linux" ]; then
        sudo apt-get update && sudo apt-get install -y "${pkgs[@]}"
    elif [ "$OS" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo "❌ Homebrew not found. Please install it: https://brew.sh/"
            exit 1
        fi
        brew install "${pkgs[@]}"
    else
        echo "❌ Unsupported OS: $OS_TYPE"
        exit 1
    fi
}

# Ensure local bin is in PATH for webi installs (k9s, etc.)
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/.config/envman/PATH.env" ] && source "$HOME/.config/envman/PATH.env"

# 0.5 Core Doctor 🏥 (Pre-flight for the installers themselves)
core_doctor() {
    local missing=()
    local deps=(curl wget gpg)
    [ "$OS" = "linux" ] && deps+=(lsb_release)

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Missing core dependencies: ${missing[*]}"
        echo "[*] Attempting to install core dependencies..."
        if [ "$NON_INTERACTIVE" = true ]; then
            pkg_install "${missing[@]}"
        else
            echo "I need to install: ${missing[*]}"
            read -p "Proceed with installation? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                pkg_install "${missing[@]}"
            else
                exit 1
            fi
        fi
    fi
    echo "✅ Core dependencies verified."
}

core_doctor

# 1. Prerequisites Doctor 🩺
# This function checks for a command and provides installation help if missing.
doctor_check() {
    local cmd=$1
    local install_cmd=$2
    local use_sudo=${3:-true}

    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd is not installed."
        echo "------------------------------------------------"
        echo "💡 How to fix ($OS):"
        if [ "$OS" = "linux" ]; then
            echo "   sudo bash -c \"$install_cmd\""
        elif [ "$OS" = "macos" ]; then
            echo "   brew install $cmd"
        fi
        echo "------------------------------------------------"
        
        # Proactively offer to run the command if in an interactive terminal
        if [ -t 0 ] && [ "$NON_INTERACTIVE" = false ]; then
            read -p "Would you like me to try installing $cmd for you? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Implement up to 3 retries for transient network errors
                for i in {1..3}; do
                    echo "[*] Attempt $i: Installing $cmd..."
                    
                    if [ "$OS" = "macos" ]; then
                        if brew install "$cmd"; then
                            echo "✅ $cmd installed successfully."
                            return 0
                        fi
                    else
                        if [ "$use_sudo" = true ]; then
                            # Use robust pattern to pass complex strings into shell
                            if sudo bash -c 'eval "$1"' -- "$install_cmd"; then
                                if command -v "$cmd" &> /dev/null; then
                                    echo "✅ $cmd installed successfully."
                                    # Re-source PATH
                                    [ -f "$HOME/.config/envman/PATH.env" ] && source "$HOME/.config/envman/PATH.env"
                                    return 0
                                fi
                            fi
                        else
                            if bash -c 'eval "$1"' -- "$install_cmd"; then
                                if command -v "$cmd" &> /dev/null; then
                                    echo "✅ $cmd installed successfully."
                                    return 0
                                fi
                            fi
                        fi
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
    if ! docker info &> /dev/null; then
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

# doctor_check calls moved to section 2.0 to avoid redundancy

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
    
    if [ "$OS" = "linux" ]; then
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
    elif [ "$OS" = "macos" ]; then
        echo "💡 Recommendation: Please start a local cluster using 'k3d', 'minikube', or 'Docker Desktop'."
        echo "   Example: k3d cluster create ai4all"
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
    if [ "$OS" = "macos" ]; then
        echo "✅ macOS detected: Skipping inotify sysctl tuning (Darwin handles this differently)."
        return 0
    fi

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
        
        if [ -t 0 ] || [ "$NON_INTERACTIVE" = true ]; then
            local proceed=false
            if [ "$NON_INTERACTIVE" = true ]; then
                proceed=true
            else
                read -p "Would you like me to optimize these kernel limits for you? (y/N) " -n 1 -r
                echo
                [[ $REPLY =~ ^[Yy]$ ]] && proceed=true
            fi

            if [ "$proceed" = true ]; then
                echo "[*] Applying kernel optimizations..."
                # Create safety backup
                sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)
                echo "✅ Created backup: /etc/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)"

                for setting in "fs.inotify.max_user_instances=$target_instances" "fs.inotify.max_user_watches=$target_watches"; do
                    local key=$(echo "$setting" | cut -d= -f1)
                    if grep -q "^$key" /etc/sysctl.conf; then
                        sudo safe_sed "s|^$key=.*|$setting|" /etc/sysctl.conf
                    else
                        echo "$setting" | sudo tee -a /etc/sysctl.conf > /dev/null
                    fi
                done
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
echo "[*] Running System Prerequisites Doctor..."
doctor_check "kubectl" 'apt-get update --fix-missing && apt-get install -y apt-transport-https ca-certificates curl && mkdir -p /etc/apt/keyrings && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list && apt-get update && apt-get install -y kubectl'
doctor_check "terraform" 'apt-get update --fix-missing && wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && apt-get update && apt-get install -y terraform'
doctor_check "helm" 'apt-get update --fix-missing && curl https://baltocdn.com/helm/signing.asc | gpg --dearmor --yes | tee /usr/share/keyrings/helm.gpg > /dev/null && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && apt-get update && apt-get install -y helm'
doctor_check "docker" 'apt-get update --fix-missing && apt-get install -y docker.io'
doctor_check "k9s" "curl -sS https://webi.sh/k9s | sh" false

docker_daemon_check
cluster_doctor
adopt_gateway_crds
kernel_doctor

# AI Laboratory Doctor (Optional but recommended)
if [ -f "ai-lab/doctor.sh" ]; then
    echo "------------------------------------------------"
    echo "[*] Checking AI Laboratory prerequisites..."
    ./ai-lab/doctor.sh
fi

# 3.5 Storage Class Verification
if ! kubectl get sc | grep -q "(default)\|default"; then
    echo "⚠️ Warning: No default StorageClass found. Loki and Prometheus PVCs might hang."
    echo "💡 Ensure your cluster (k3s/minikube/kind) has a default local provisioner."
else
    echo "✅ Default StorageClass exists for Persistent Volumes."
fi

# 3.8 Linkerd Certificate Generation
if [ ! -f ".certs/issuer.crt" ] || [ ! -f ".certs/issuer.key" ] || [ ! -f ".certs/trust-anchor.crt" ]; then
    echo "⚠️ Linkerd mTLS certificates not found. Generating them via Python cryptography..."
    
    # Ensure cryptography is installed
    if ! python3 -c "import cryptography" &> /dev/null; then
        echo "[*] Installing python3-cryptography..."
        sudo apt-get update && sudo apt-get install -y python3-cryptography
    fi

    mkdir -p .certs
    python3 scripts/internal/generate_certs.py
    
    # Fix permissions if needed
    chmod 600 .certs/issuer.key .certs/trust-anchor.key 2>/dev/null || true
    echo "✅ Linkerd certificates generated successfully."
else
    echo "✅ Linkerd certificates found in .certs/."
fi

# 3.9 Backend Detection & Adaptive Mode (DX-First)
if [ -f "backend.tf" ]; then
    echo "------------------------------------------------"
    echo "🚀 Enterprise Mode Active (Remote Backend Enabled)"
    
    # Pre-flight for AWS CLI
    doctor_check "aws" "apt-get update && apt-get install -y awscli"

    SHOULD_BOOTSTRAP=false
    if [ "$AUTO_BOOTSTRAP" = "true" ]; then
        SHOULD_BOOTSTRAP=true
    elif [ -t 0 ]; then
        read -p "Would you like me to bootstrap the remote state assets (S3/DynamoDB)? (y/N) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && SHOULD_BOOTSTRAP=true
    fi

    if [ "$SHOULD_BOOTSTRAP" = "true" ]; then
        ./scripts/bootstrap-backend.sh
    fi
elif [ -f ".backend.tf.enterprise" ]; then
    echo "------------------------------------------------"
    echo "🛡️  Local Lab Mode Active (Zero-Config Execution)"
    echo "💡 Note: To see the '10/10 Enterprise Backend' in action, run 'make enterprise-on'."
fi

# 4. Terraform Initialization
echo "------------------------------------------------"
echo "Initializing Terraform..."
max_retries=3
count=1
success=false

while [ $count -le $max_retries ]; do
    echo "[*] Attempt $count: running terraform init..."
    if terraform init; then
        success=true
        break
    fi
    echo "⚠️ Terraform init failed. Retrying in 10 seconds... ($count/$max_retries)"
    sleep 10
    count=$((count + 1))
done

if [ "$success" = false ]; then
    echo "❌ Terraform init failed after $max_retries attempts. Please check your internet connection."
    exit 1
fi

# 5. Terraform Apply Logic
if [[ "$*" == *"--stage-1"* ]]; then
    echo "Applying Base Helm Charts (CRDs & Controllers)..."
    terraform apply \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.argocd \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.observability \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.keda \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.trivy \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.kyverno \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.linkerd \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.vault \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.minio \
      -target=module.platform.module.sre_kernel.kubernetes_namespace.ollama \
      -target=module.platform.module.sre_kernel.helm_release.chaos_mesh \
      -target=module.platform.module.sre_kernel.helm_release.kyverno \
      -target=module.platform.module.sre_kernel.helm_release.argo_rollouts \
      -target=module.platform.module.sre_kernel.helm_release.argocd \
      -target=module.platform.module.sre_kernel.helm_release.kube_prometheus_stack \
      -target=module.platform.module.sre_kernel.helm_release.linkerd_crds \
      -target=module.platform.module.sre_kernel.helm_release.vault \
      -target=module.platform.module.sre_kernel.helm_release.trivy \
      -target=module.platform.module.sre_kernel.helm_release.keda \
      -target=module.platform.module.sre_kernel.kubernetes_deployment.ollama \
      -auto-approve
    exit 0
elif [[ "$*" == *"--stage-2"* ]]; then
    echo "Applying full Infrastructure..."
    terraform apply -auto-approve
    exit 0
else
    # Default behavior: Run both stages
    $0 --stage-1
    echo "------------------------------------------------"
    echo "⏳ Waiting for CRDs to register in the Kubernetes API..."
    sleep 20
    $0 --stage-2
fi

echo "------------------------------------------------"
echo "⏳ Waiting for core dashboard endpoints and GitOps sync..."
# Wait for ArgoCD app to be healthy (GitOps sync)
# We use || true here because sometimes ArgoCD reporting is slightly delayed even when pods are running
kubectl wait --for=jsonpath='{.status.health.status}'=Healthy application/ai4all-sre -n argocd --timeout=300s || echo "⚠️ Warning: ArgoCD app sync is taking longer than expected."

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/kube-prometheus-grafana -n observability --timeout=300s
kubectl rollout status deployment/goalert -n incident-management --timeout=10s || echo "⚠️ Warning: GoAlert deployment not found or not ready. Continuing..."

# Wait for Argo Rollout instead of Deployment for the frontend
if kubectl get rollout frontend -n online-boutique &> /dev/null; then
    echo "Checking Argo Rollout status for frontend..."
    kubectl get rollout frontend -n online-boutique -o jsonpath='{"Status: "}{.status.phase}{"\n"}'
else
    echo "⚠️ Warning: frontend Rollout not found yet."
fi

kubectl rollout status deployment/chaos-dashboard -n chaos-testing --timeout=10s || echo "⚠️ Warning: chaos-dashboard deployment not found or not ready. Continuing..."

echo "------------------------------------------------"
echo "✅ Autonomous Laboratory Setup Complete!"
echo "------------------------------------------------"
echo "The Multi-Agent System (Director, Network, DB, Compute) is already running in the cluster."
echo "You can view its logs via:"
echo "  kubectl logs -f deployment/ai-agent -n observability"
echo "------------------------------------------------"
echo -e "\033[1;33m🚀 PHASE 2: AI MODEL SPECIALIZATION (Optional)\033[0m"
echo "To transform the base LLM into an elite SRE-Kernel brain specialized in this lab's context:"
echo "  ./ai-lab/specialize-model.sh"
echo "------------------------------------------------"
echo "🚀 Launching Dashboards..."
# exec ./scripts/start-dashboards.sh
echo "✅ Setup complete. Dashboards can be started with ./scripts/start-dashboards.sh"
