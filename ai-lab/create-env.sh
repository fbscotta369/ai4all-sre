#!/bin/bash

# AI Laboratory Environment Creator 🚀
# Automates the creation of the 'sre-ai-lab' environment with optimized ML dependencies.

set -e

ENV_NAME="sre-ai-lab"
PYTHON_VERSION="3.10"

echo "Starting AI Laboratory Environment Setup..."
echo "------------------------------------------------"

# 1. Conda Check
if ! command -v conda &> /dev/null; then
    # Probe common locations if not in PATH (same as doctor.sh)
    FOR_PROBE=("$HOME/miniconda3/bin/conda" "$HOME/anaconda3/bin/conda" "/opt/conda/bin/conda")
    for probe in "${FOR_PROBE[@]}"; do
        if [ -f "$probe" ]; then
            eval "$($probe shell.bash hook)"
            break
        fi
    done
fi

if ! command -v conda &> /dev/null; then
    echo "❌ Conda not found. Please run './ai-lab/doctor.sh' first to install it."
    exit 1
fi

# 2. Environment Creation
if conda info --envs | grep -q "$ENV_NAME"; then
    echo "✅ Environment '$ENV_NAME' already exists."
    read -p "Would you like to recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "[*] Removing existing environment..."
        conda remove --name "$ENV_NAME" --all -y
        echo "[*] Creating new environment..."
        conda create --name "$ENV_NAME" python="$PYTHON_VERSION" -y
    fi
else
    echo "[*] Creating environment '$ENV_NAME'..."
    conda create --name "$ENV_NAME" python="$PYTHON_VERSION" -y
fi

# 3. Dependency Installation
echo "[*] Installing AI dependencies (this may take a few minutes)..."

# We use 'conda run' to execute commands inside the environment without requiring a shell restart
conda run -n "$ENV_NAME" pip install --upgrade pip
conda run -n "$ENV_NAME" pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
conda run -n "$ENV_NAME" pip install --no-deps "xformers<0.0.27" "trl<0.9.0" peft accelerate transformers

echo "------------------------------------------------"
echo "✅ AI Laboratory Environment '$ENV_NAME' is ready!"
echo "------------------------------------------------"
echo "To started working, run:"
echo "   conda activate $ENV_NAME"
echo "------------------------------------------------"
