#!/bin/bash

# AI4ALL-SRE AI Laboratory Doctor 🩺
# This script ensures your environment is ready for Model Fine-Tuning.

set -e

echo "Starting AI Laboratory Prerequisites Check..."
echo "------------------------------------------------"

# 0. Early Repository Cleanup
# Conflicted or broken repositories cause 'apt update' to fail globally.
# We clear our managed repositories early to ensure a fresh state.
echo "[*] Cleaning up potential repository conflicts..."
sudo rm -f /etc/apt/sources.list.d/archive_uri-https_developer_download_nvidia_com_compute_cuda_repos_ubuntu2204_x86_64_-jammy.list
sudo rm -f /etc/apt/sources.list.d/nvidia-cuda.list
sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list

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
                if [ "$use_sudo" = true ]; then
                    sudo bash -c "$install_cmd"
                else
                    eval "$install_cmd"
                fi
                echo "✅ $description installed successfully."
                return 0
            else
                echo "⚠️ Please install $description manually to proceed."
                return 1
            fi
        else
            echo "💡 Manual fix:"
            echo "   $install_cmd"
            return 1
        fi
    fi
    echo "✅ $description is installed."
}

# 1. GPU Check & Driver Installation
echo "Checking for NVIDIA GPU Readiness..."
if ! command -v nvidia-smi &> /dev/null; then
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
            echo "💡 Add this to your ~/.bashrc: export PATH=/usr/local/cuda-12.1/bin:\$PATH"
        fi
    fi
else
    echo "✅ CUDA Toolkit is installed."
fi

# 3. NVIDIA Container Toolkit Check
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

# 4. Conda/Mamba Check
if ! command -v conda &> /dev/null && ! command -v mamba &> /dev/null; then
    echo "❌ Conda/Mamba not found."
    if [ -t 0 ]; then
        read -p "Would you like me to install Miniconda for you? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Downloading Miniconda installer..."
            curl -L https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o miniconda.sh
            bash miniconda.sh -b -p "$HOME/miniconda3"
            rm miniconda.sh
            echo "✅ Miniconda installed to $HOME/miniconda3."
            export PATH="$HOME/miniconda3/bin:$PATH"
        else
            echo "⚠️ Please install Conda manually: https://docs.conda.io/en/latest/miniconda.html"
            exit 1
        fi
    else
        echo "💡 Install Miniconda: https://docs.conda.io/en/latest/miniconda.html"
        exit 1
    fi
else
    echo "✅ Conda/Mamba is installed."
fi

# 5. Pip Check
doctor_check "pip" "apt-get update && apt-get install -y python3-pip" "Pip" true

# 6. Summary & Next Steps
echo "------------------------------------------------"
echo "✅ AI Laboratory Prerequisites Check Complete!"
echo "------------------------------------------------"
echo "🚀 You are ready to create your AI environment:"
echo "   conda create --name sre-ai-lab python=3.10 -y"
echo "   conda activate sre-ai-lab"
echo "   pip install unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
echo "------------------------------------------------"
