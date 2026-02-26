#!/bin/bash

# AI4ALL-SRE AI Laboratory Doctor 🩺
# This script ensures your environment is ready for Model Fine-Tuning.

set -e

echo "Starting AI Laboratory Prerequisites Check..."
echo "------------------------------------------------"

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

# 1. GPU Check
echo "Checking for NVIDIA GPU Readiness..."
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ Error: NVIDIA Drivers not found. 'nvidia-smi' is required for fine-tuning."
    echo "💡 Please install NVIDIA Drivers (Recommended: 535+) and CUDA 12.1+."
    exit 1
else
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader)
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,unit=MiB | head -n 1)
    echo "✅ GPU Found: $GPU_NAME ($VRAM VRAM)"
    
    # Check VRAM - RTX 3060 (12GB) is about 12000 MiB
    VRAM_VAL=$(echo "$VRAM" | awk '{print $1}')
    if [ "$VRAM_VAL" -lt 8000 ]; then
        echo "⚠️ Warning: You have less than 8GB of VRAM. Fine-tuning Llama-3 might be unstable."
    fi
fi

# 2. Conda/Mamba Check
if ! command -v conda &> /dev/null && ! command -v mamba &> /dev/null; then
    echo "❌ Conda/Mamba not found. Environment management is highly recommended."
    echo "------------------------------------------------"
    if [ -t 0 ]; then
        read -p "Would you like me to install Miniconda for you? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Downloading Miniconda installer..."
            curl -L https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o miniconda.sh
            bash miniconda.sh -b -p "$HOME/miniconda3"
            rm miniconda.sh
            echo "✅ Miniconda installed to $HOME/miniconda3."
            echo "💡 Run 'source ~/miniconda3/bin/activate' to start using conda."
            # We don't exit here, but the user will need to restart their shell to get 'conda' in PATH
            # For the current script, we can add it to PATH
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

# 3. Pip Check
doctor_check "pip" "apt-get update && apt-get install -y python3-pip" "Pip" true

# 4. Summary & Next Steps
echo "------------------------------------------------"
echo "✅ AI Laboratory Prerequisites Check Complete!"
echo "------------------------------------------------"
echo "🚀 You are ready to create your AI environment:"
echo "   conda create --name sre-ai-lab python=3.10 -y"
echo "   conda activate sre-ai-lab"
echo "------------------------------------------------"
