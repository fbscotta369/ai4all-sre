#!/bin/bash

# AI4ALL-SRE AI Laboratory Doctor 🩺
# This script ensures your environment is ready for Model Fine-Tuning.

set -e

echo "Starting AI Laboratory Prerequisites Check..."
echo "------------------------------------------------"

# 0. Environment Bootstrap 🌐
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

# Function to install packages cross-platform
pkg_install() {
    local pkgs=("$@")
    if [ "$OS" = "linux" ]; then
        sudo apt-get update && sudo apt-get install -y "${pkgs[@]}"
    elif [ "$OS" = "macos" ]; then
        brew install "${pkgs[@]}"
    fi
}

# 0. Early Repository Cleanup (Linux only)
if [ "$OS" = "linux" ]; then
    echo "[*] Cleaning up potential repository conflicts..."
    sudo -n rm -f /etc/apt/sources.list.d/archive_uri-https_developer_download_nvidia_com_compute_cuda_repos_ubuntu2204_x86_64_-jammy.list 2>/dev/null || true
    sudo -n rm -f /etc/apt/sources.list.d/nvidia-cuda.list 2>/dev/null || true
    sudo -n rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list 2>/dev/null || true
fi

# Function to check for a command and optionally install it
doctor_check() {
    local cmd=$1
    local install_cmd=$2
    local description=$3
    local use_sudo=${4:-true}

    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ $description ($cmd) is not installed."
        echo "------------------------------------------------"
        
        if [ -t 0 ]; then
            read -p "Would you like me to try installing $description for you? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "[*] Installing $description..."
                if [ "$OS" = "macos" ]; then
                    brew install "$cmd"
                else
                    if [ "$use_sudo" = true ]; then
                        sudo bash -c 'eval "$1"' -- "$install_cmd"
                    else
                        bash -c 'eval "$1"' -- "$install_cmd"
                    fi
                fi
                
                if command -v "$cmd" &> /dev/null; then
                    echo "✅ $description installed successfully."
                    return 0
                else
                    echo "❌ Failed to install $description."
                    return 1
                fi
            else
                echo "⚠️ Please install $description manually to proceed."
                return 1
            fi
        else
            echo "💡 Manual fix:"
            if [ "$OS" = "macos" ]; then
                echo "   brew install $cmd"
            else
                echo "   $install_cmd"
            fi
            return 1
        fi
    fi
    echo "✅ $description is installed."
}

# 1. GPU Check & Driver Installation
echo "Checking for NVIDIA GPU Readiness..."
if [ "$OS" = "macos" ]; then
    echo "✅ macOS detected: Checking for Apple Silicon (Metal) readiness..."
    if sysctl -a | grep -q "brand: Apple"; then
        echo "✅ Apple Silicon detected. Metal performance shaders will be used."
    else
        echo "⚠️ Intel Mac detected. CPU-only execution will be prioritized."
    fi
elif ! command -v nvidia-smi &> /dev/null; then
    echo "[*] nvidia-smi not found. Checking for NVIDIA hardware..."
    if lspci | grep -i nvidia &> /dev/null; then
        echo "✅ NVIDIA Hardware detected via lspci."
        if [ -t 0 ]; then
            read -p "NVIDIA drivers are missing. Would you like me to autoinstall them? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "[*] Running 'ubuntu-drivers autoinstall'..."
                sudo ubuntu-drivers autoinstall
                echo "✅ Drivers installed. A REBOOT IS REQUIRED before nvidia-smi will work."
                echo "⚠️ Please reboot and run this script again."
                exit 0
            fi
        else
            echo "💡 Manual fix: sudo ubuntu-drivers autoinstall && reboot"
            exit 1
        fi
    else
        echo "❌ Error: No NVIDIA GPU detected. Hardware is required for fine-tuning."
        exit 1
    fi
else
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
    # Portable query: skip 'unit=MiB' as older versions don't support it
    VRAM_RAW=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -n 1)
    
    # Robust numeric extraction: strip everything except digits
    VRAM_VAL=$(echo "$VRAM_RAW" | grep -oE '[0-9]+' | head -n 1)
    
    if [ -n "$VRAM_VAL" ]; then
        echo "✅ GPU Found: $GPU_NAME (${VRAM_VAL}MiB approx)"
        if [ "$VRAM_VAL" -lt 8000 ]; then
            echo "⚠️ Warning: You have less than 8GB of VRAM. Fine-tuning Llama-3 might be unstable."
        fi
    else
        echo "⚠️ Warning: Could not parse VRAM value from '$VRAM_RAW'. Skipping VRAM check."
    fi
fi

# 2. CUDA 12.1 Check & Installation
if [ "$OS" = "linux" ]; then
    if ! command -v nvcc &> /dev/null; then
        echo "❌ CUDA Toolkit (nvcc) not found."
        if [ -t 0 ]; then
        read -p "Would you like me to install CUDA 12.1 Toolkit? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Setting up NVIDIA repository and installing CUDA 12.1 Toolkit..."
            # Modern GPG handling (Ubuntu 22.04)
            wget -qO- https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub | \
                sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-cuda.gpg
            
            echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" | \
                sudo tee /etc/apt/sources.list.d/nvidia-cuda.list
            
            wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
            sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
            
            sudo apt-get update
            # Use cuda-toolkit instead of full cuda package to avoid driver conflicts
            sudo apt-get -y install cuda-toolkit-12-1
            echo "✅ CUDA 12.1 Toolkit installed."
            if ! grep -q "/usr/local/cuda-12.1/bin" "$HOME/.bashrc"; then
                read -p "Would you like me to add CUDA to your ~/.bashrc for persistence? (y/N) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
                    echo "✅ Created backup: ~/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
                    echo 'export PATH=/usr/local/cuda-12.1/bin:$PATH' >> "$HOME/.bashrc"
                    echo "✅ Added to ~/.bashrc."
                fi
            fi
        fi
    fi
else
    echo "✅ CUDA Toolkit is installed."
    if ! grep -q "/usr/local/cuda-12.1/bin" "$HOME/.bashrc" && [ -t 0 ]; then
        read -p "CUDA is installed but not in your ~/.bashrc. Add it now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
            echo "✅ Created backup: ~/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
            echo 'export PATH=/usr/local/cuda-12.1/bin:$PATH' >> "$HOME/.bashrc"
            echo "✅ Added to ~/.bashrc."
        fi
    fi
    fi
fi

# 3. NVIDIA Container Toolkit Check (Linux only)
if [ "$OS" = "linux" ]; then
    if ! command -v nvidia-ctk &> /dev/null; then
        echo "❌ NVIDIA Container Toolkit not found. This is needed for GPU support in Docker/K8s."
        if [ -t 0 ]; then
            read -p "Would you like me to install the NVIDIA Container Toolkit? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "[*] Configuring NVIDIA Container Toolkit repository..."
                curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
                
                # Use the official stable URL for amd64 directly
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/amd64 /" | \
                    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
                
                sudo apt-get update
                sudo apt-get install -y nvidia-container-toolkit
                echo "✅ NVIDIA Container Toolkit installed."
            fi
        fi
    else
        echo "✅ NVIDIA Container Toolkit is installed."
    fi
fi

# 4. Conda/Mamba Check
if ! command -v conda &> /dev/null && ! command -v mamba &> /dev/null; then
    echo "[*] Conda/Mamba not in PATH. Probing common locations..."
    FOR_PROBE=("$HOME/miniconda3/bin/conda" "$HOME/anaconda3/bin/conda" "/opt/conda/bin/conda")
    CONDA_FOUND=false
    CONDA_CMD="" # Initialize CONDA_CMD
    for probe in "${FOR_PROBE[@]}"; do
        if [ -f "$probe" ]; then
            CONDA_CMD="$probe" # Store the full path to the conda executable
            CONDA_FOUND=true
            break
        fi
    done

    if [ "$CONDA_CMD" != "" ]; then
        echo -e "✅ Conda found at $CONDA_CMD (added to PATH for this session)."
        CONDA_PATH=$(dirname "$CONDA_CMD")
        export PATH="$CONDA_PATH:$PATH"
    fi

    if [ "$CONDA_FOUND" = false ]; then
        echo "❌ Conda/Mamba not found."
        if [ -t 0 ]; then
            read -p "Would you like me to install Miniconda for you? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "[*] Downloading Miniconda installer..."
                curl -L https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o miniconda.sh
                
                # Check if directory exists
                INSTALL_PATH="$HOME/miniconda3"
                if [ -d "$INSTALL_PATH" ]; then
                    echo "⚠️  Directory $INSTALL_PATH already exists."
                    read -p "Would you like to try updating the existing installation? (y/N) " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        bash miniconda.sh -b -u -p "$INSTALL_PATH"
                    else
                        echo "❌ Installation aborted to avoid overwriting $INSTALL_PATH."
                        rm miniconda.sh
                        exit 1
                    fi
                else
                    bash miniconda.sh -b -p "$INSTALL_PATH"
                fi
                
                rm miniconda.sh
                echo "✅ Miniconda installed/updated at $INSTALL_PATH."
                export PATH="$INSTALL_PATH/bin:$PATH"
                
                if [ -t 0 ]; then
                    read -p "Would you like to run 'conda init' to make this persistent? (y/N) " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
                        echo "✅ Created backup: ~/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
                        "$INSTALL_PATH/bin/conda" init bash
                    fi
                fi
            else
                echo "⚠️ Please install Conda manually: https://docs.conda.io/en/latest/miniconda.html"
                exit 1
            fi
        else
            echo "💡 Install Miniconda: https://docs.conda.io/en/latest/miniconda.html"
            exit 1
        fi
    fi
else
    echo "✅ Conda/Mamba is installed."
    # Check if conda init is needed
    if ! grep -q "conda initialize" "$HOME/.bashrc" && [ -t 0 ]; then
        read -p "Conda is installed but not initialized in your ~/.bashrc. Run 'conda init' now? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
            echo "✅ Created backup: ~/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
            conda init bash
        fi
    fi
    
    # PROACTIVE: Accept Anaconda ToS for all discovery paths
    echo "[*] Ensuring Anaconda Terms of Service are accepted..."
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true
fi

# 5. Pip Check
doctor_check "pip" "apt-get update && apt-get install -y python3-pip" "Pip" true

# 6. Ollama CLI & Connectivity Check
echo "Checking for Ollama CLI and Cluster Connectivity..."
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama CLI is not installed."
    if [ -t 0 ]; then
        read -p "Would you like me to install the Ollama CLI for you? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Installing Ollama CLI..."
            if [ "$OS" = "macos" ]; then
                brew install ollama
            else
                curl -fsSL https://ollama.com/install.sh | sh
            fi
            echo "✅ Ollama CLI installed successfully."
        fi
    else
        echo "💡 Manual fix:"
        [ "$OS" = "macos" ] && echo "   brew install ollama" || echo "   curl -fsSL https://ollama.com/install.sh | sh"
    fi
fi

# 7. Cluster Ollama Connectivity Check
echo "[*] Verifying Connectivity to Cluster-Resident Ollama..."
if kubectl get svc ollama -n ollama &> /dev/null; then
    echo "✅ Ollama service found in cluster."
    # Port-forward if needed to check from local machine, but here we just check readiness
    READY_REPLICAS=$(kubectl get deployment ollama -n ollama -o jsonpath='{.status.readyReplicas}')
    if [[ "$READY_REPLICAS" -gt 0 ]]; then
        echo "✅ Ollama deployment is READY in the cluster."
    else
        echo "⚠️  Ollama deployment is NOT READY yet. Waiting for rollout..."
    fi
else
    echo "❌ Ollama service NOT found in cluster. Please run ./setup.sh"
fi

# 8. Summary & Next Steps
echo "------------------------------------------------"
echo "✅ AI Laboratory Prerequisites Check Complete!"
echo "------------------------------------------------"
echo "⚠️ IMPORTANT: Please run 'source ~/.bashrc' or restart your terminal"
echo "   to ensure all changes are applied to your current session."
echo "------------------------------------------------"
echo "🚀 You are ready to create your AI environment:"
echo "   conda create --name sre-ai-lab python=3.10 -y"
echo "   conda activate sre-ai-lab"
echo "   pip install unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
echo "------------------------------------------------"
