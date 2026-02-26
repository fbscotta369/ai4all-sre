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

# 2. Environment Creation/Verification
if conda info --envs | grep -q "$ENV_NAME"; then
    echo "✅ Environment '$ENV_NAME' already exists."
    # If in an interactive terminal, offer recreation. Otherwise, proceed to dependency verification.
    if [ -t 0 ]; then
        read -t 5 -n 1 -r -p "Would you like to RECREATE it? (y/N) [Timeout in 5s assumes N]: " || REPLY="n"
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "[*] Removing existing environment..."
            conda remove --name "$ENV_NAME" --all -y
            echo "[*] Creating new environment..."
            conda create --name "$ENV_NAME" python="$PYTHON_VERSION" -y
        fi
    fi
else
    echo "[*] Creating environment '$ENV_NAME'..."
    conda create --name "$ENV_NAME" python="$PYTHON_VERSION" -y
fi

# 3. Dependency Installation (Tier-1 Stability Pin: Torch 2.4.0 + CUDA 12.1)
echo "[*] Installing AI dependencies (Stable Pin: Torch 2.4.0 + CUDA 12.1)..."

# We use 'conda run' to execute commands inside the environment
conda run -n "$ENV_NAME" pip install --upgrade pip

echo "[*] Phase 1/2: Forcing Base PyTorch 2.4.0 (CUDA 12.1)..."
# Force reinstall and no-cache to ensure we purge any 2.6.0 artifacts
conda run -n "$ENV_NAME" pip install --force-reinstall --no-cache-dir torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu121

echo "[*] Phase 2/2: Installing Unsloth Stack..."
conda run -n "$ENV_NAME" pip install --no-cache-dir "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
conda run -n "$ENV_NAME" pip install --no-cache-dir --no-deps "xformers==0.0.27.post2" "trl<0.9.0" peft accelerate transformers

echo "[*] Verifying Version Alignment..."
conda run -n "$ENV_NAME" python -c "import torch; import unsloth; print(f'--- DIAGNOSTICS ---\nTorch: {torch.__version__}\nUnsloth: {unsloth.__version__}\nCUDA: {torch.version.cuda}\n-------------------')"

echo "------------------------------------------------"
echo "✅ AI Laboratory Environment '$ENV_NAME' is ready!"
echo "------------------------------------------------"
echo "To started working, run:"
echo "   conda activate $ENV_NAME"
echo "------------------------------------------------"
