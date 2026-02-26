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

# 3. Dependency Installation (High-Performance Stability Pin)
echo "[*] Phase 1/3: Nuclear Purge of existing ML artifacts..."
conda run -n "$ENV_NAME" pip uninstall -y torch torchvision torchaudio unsloth unsloth-zoo triton xformers trl peft accelerate transformers 2>/dev/null || true

echo "[*] Phase 2/3: Installing Production-Grade PyTorch 2.4.0 (CUDA 12.1)..."
conda run -n "$ENV_NAME" pip install --no-cache-dir torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu121

echo "[*] Phase 3/3: Tailoring Unsloth & SRE-Specific Neighbors..."
conda run -n "$ENV_NAME" pip install --no-cache-dir "unsloth @ git+https://github.com/unslothai/unsloth.git"
conda run -n "$ENV_NAME" pip install --no-cache-dir --no-deps xformers==0.0.27.post2 trl==0.8.6 peft accelerate transformers

echo "[*] Verifying Package Residency..."
conda run -n "$ENV_NAME" pip list | grep -E "torch|unsloth|xformers|triton"

echo "[*] Final Integration Test..."
conda run -n "$ENV_NAME" python -c "import torch; print(f'Torch: {torch.__version__}'); import unsloth; print(f'Unsloth: {unsloth.__version__}')" || { echo "❌ Integration Test Failed. Retrying with dependency cleanup..."; exit 1; }

echo "------------------------------------------------"
echo "✅ AI Laboratory Environment '$ENV_NAME' is ready!"
echo "------------------------------------------------"
echo "To started working, run:"
echo "   conda activate $ENV_NAME"
echo "------------------------------------------------"
