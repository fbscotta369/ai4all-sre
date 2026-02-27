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

# 3. Dependency Installation (Lean High-Performance Stack)
echo "[*] Phase 1/3: Nuclear Purge of existing ML artifacts & Redundant Extras..."
# Explicitly purge torchao as it often causes the 'int1' conflict in unsloth_zoo
conda run -n "$ENV_NAME" pip uninstall -y torch torchvision torchaudio unsloth unsloth-zoo triton xformers trl peft accelerate transformers torchao 2>/dev/null || true

echo "[*] Phase 2/3: Installing Stable base: PyTorch 2.4.0 + CUDA 12.1..."
# We go back to 2.4.0 but with a clean slate to avoid 'int1' errors
conda run -n "$ENV_NAME" pip install --no-cache-dir torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu121

echo "[*] Phase 3/3: Tailoring Lean Unsloth & SRE-Specific Neighbors..."
# Install neighbors FIRST and pinned to block newer versions from pulling in torchao
conda run -n "$ENV_NAME" pip install --no-cache-dir --no-deps "transformers==4.44.2" "trl==0.8.6" "xformers==0.0.26.post1" peft accelerate

# Install unsloth core and zoo strictly WITHOUT dependencies to prevent torchao contamination
conda run -n "$ENV_NAME" pip install --no-cache-dir --no-deps "unsloth @ git+https://github.com/unslothai/unsloth.git"
conda run -n "$ENV_NAME" pip install --no-cache-dir --no-deps "unsloth_zoo @ git+https://github.com/unslothai/unsloth-zoo.git"

# Final Quarantine: Force uninstall torchao if it somehow leaked in
conda run -n "$ENV_NAME" pip uninstall -y torchao 2>/dev/null || true

echo "[*] Applying Surgical Stability Patch to Unsloth-Zoo..."
# 1. Bypassing Inductor Config check
PATCH_FILE="/home/fb/miniconda3/envs/$ENV_NAME/lib/python3.10/site-packages/unsloth_zoo/temporary_patches/common.py"
if [ -f "$PATCH_FILE" ]; then
    sed -i "s/inspect.getsource(torch._inductor.config)/'# Bypassed by SRE-Kernel Patch'/" "$PATCH_FILE"
fi

# 2. Monkey-patching Torch to support int1 if needed by transformers
TORCH_INIT="/home/fb/miniconda3/envs/$ENV_NAME/lib/python3.10/site-packages/torch/__init__.py"
if [ -f "$TORCH_INIT" ] && ! grep -q "int1 = int" "$TORCH_INIT"; then
    echo "torch.int1 = torch.int8 # SRE-Kernel Patch" >> "$TORCH_INIT"
fi

echo "[*] Verifying Package Residency..."
conda run -n "$ENV_NAME" pip list | grep -E "torch|unsloth|xformers|triton"

echo "[*] Final Integration Test..."
export UNSLOTH_COMPILE_DISABLE=1
conda run -n "$ENV_NAME" python -c "import torch; print(f'Torch: {torch.__version__}'); import unsloth; print(f'Unsloth: {unsloth.__version__}'); from unsloth import FastLanguageModel; print('Integrity Check: OK')" || { echo "❌ Integration Test Failed."; exit 1; }

echo "------------------------------------------------"
echo "✅ AI Laboratory Environment '$ENV_NAME' is ready!"
echo "------------------------------------------------"
echo "To started working, run:"
echo "   conda activate $ENV_NAME"
echo "------------------------------------------------"
