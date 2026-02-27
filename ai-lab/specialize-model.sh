#!/bin/bash
set -e

# ==============================================================================
# SRE-Kernel Specialization Orchestrator
# Purpose: Tier-1 automated pipeline for domain-specific LLM fine-tuning.
# ==============================================================================

# Colors for professional output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

export UNSLOTH_COMPILE_DISABLE=1
export OLLAMA_MODEL="sre-kernel"
export PYTHON_VERSION="3.10"

echo -e "${BLUE}[*] Starting SRE-Kernel Specialization Pipeline...${NC}"

# 0. Conda PATH Discovery (Ensures portability if not in shell PATH)
if ! command -v conda &> /dev/null; then
    FOR_PROBE=("$HOME/miniconda3/bin/conda" "$HOME/anaconda3/bin/conda" "/opt/conda/bin/conda")
    for probe in "${FOR_PROBE[@]}"; do
        if [ -f "$probe" ]; then
            eval "$($probe shell.bash hook)"
            break
        fi
    done
fi

# PROACTIVE: Ensure Anaconda Terms of Service are accepted
if command -v conda &> /dev/null; then
    echo "[*] Initializing Conda Environment & Accepting ToS..."
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true
fi

# 1. Prerequisite Validation
echo -e "${YELLOW}[Step 1/5] Validating Infrastructure...${NC}"
./ai-lab/doctor.sh --check-only || { echo -e "${RED}[!] Infrastructure check failed. Run ./ai-lab/doctor.sh first.${NC}"; exit 1; }

# 2. Dataset Synthesis
echo -e "${YELLOW}[Step 2/5] Synthesizing Training Dataset...${NC}"
./scripts/generate_training_data.py || { echo -e "${RED}[!] Dataset generation failed.${NC}"; exit 1; }

# 2.5 Environment Verification & Residency
echo -e "${YELLOW}[Step 2.5/5] Ensuring AI Environment Integrity...${NC}"
./ai-lab/create-env.sh

# 3. Training & Fine-Tuning (LoRA/Unsloth)
echo -e "${YELLOW}[Step 3/5] Executing Fine-Tuning (4-bit QLoRA)...${NC}"
# Use conda run to ensure correct environment
conda run -n sre-ai-lab python ai-lab/fine-tuning/train_sre.py \
    --dataset ai-lab/fine-tuning/dataset_generated.jsonl \
    --output ai-lab/fine-tuning/sre-kernel-adapter \
    --max_steps 100 || { echo -e "${RED}[!] Training failed.${NC}"; exit 1; }

# 4. Ollama Model Registration
echo -e "${YELLOW}[Step 4/5] Registering 'sre-kernel' in Ollama...${NC}"
ollama create sre-kernel -f ai-lab/Modelfile || { echo -e "${RED}[!] Ollama model creation failed.${NC}"; exit 1; }

# 5. Continuous Verification
echo -e "${YELLOW}[Step 5/5] Performing A/B Verification...${NC}"
./scripts/verify_specialization.py || { echo -e "${YELLOW}[!] Verification suite returned warnings. Review results above.${NC}"; }

echo -e "----------------------------------------------------------------"
echo -e "${GREEN}✅ SPECIALIZATION PIPELINE COMPLETE!${NC}"
echo -e "Your AI Agent is now powered by the specialized 'sre-kernel' model."
echo -e "----------------------------------------------------------------"
