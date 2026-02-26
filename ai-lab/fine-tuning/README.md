# 🧪 SRE AI Fine-Tuning Lab: Local Execution Guide

This guide provides the step-by-step instructions to fine-tune Llama 3 8B into a specialized **"SRE-Kernel"** model using your local desktop hardware (RTX 3060 12GB).

## 🧰 Prerequisites

### Hardware Optimization
Your machine is ideally spec'd for this:
- **GPU**: RTX 3060 (12GB VRAM) — Crucial for 4-bit QLoRA.
- **RAM**: 128GB — Allows for large dataset buffering and CPU-offloading.

### Software Stack
We recommend using **Linux (Kubuntu 22.04)** for maximum performance.
1.  **NVIDIA Drivers**: Ensure you have CUDA 12.1+ installed.
2.  **Conda/Mamba**: For clean environment management.
3.  **Unsloth**: The fastest library for local Llama fine-tuning.

## 🏁 Step 0: Prerequisites Doctor 🩺

Before creating your environment, run the specialized AI environment doctor to verify your GPU and Conda status:

```bash
./ai-lab/doctor.sh
```
*This handles NVIDIA driver verification and Miniconda bootstrapping.*

## 🚀 Environment Setup

```bash
# Create a specialized AI environment
conda create --name sre-ai-lab python=3.10 -y
conda activate sre-ai-lab

# Install Unsloth and dependencies
pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
pip install --no-deps "xformers<0.0.27" "trl<0.9.0" peft acceleration transformers
```

## 📂 Dataset Preparation

The model learns from your **Post-Mortems** and **Kubernetes logs**.
1.  Collect your `.md` post-mortems from the `post-mortems/` directory.
2.  Format them into the `dataset_template.jsonl` structure.
3.  Standardize the instruction: `"Analyze the following Kubernetes incident and provide a Root Cause Analysis (RCA)."`.

## 🚀 Phase-by-Phase Execution

Follow these exact steps to begin your first training run.

### 1. Environment Initialization
```bash
# Verify GPU and Conda readiness
./ai-lab/doctor.sh

# Create and activate the specialized environment
conda create --name sre-ai-lab python=3.10 -y
conda activate sre-ai-lab

# Install the high-performance Unsloth stack
pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
pip install --no-deps "xformers<0.0.27" "trl<0.9.0" peft accelerate transformers
```

### 2. Dataset Synthesis
The model requires a `.jsonl` file. You can generate this from your existing post-mortems:
```bash
# Example: Convert a markdown post-mortem into a training pair
# Instruction: "Analyze the incident context and provide a technical RCA."
# Input: [Raw Log/Post-Mortem Content]
# Output: [The expected RCA outcome]

# Verify your dataset format
head -n 1 dataset_template.jsonl
```

### 3. Training Execution (Managed via Unsloth)
Run the training script with optimized settings for the RTX 3060:
```bash
python train_sre.py \
    --dataset ./dataset_template.jsonl \
    --output ./sre-kernel-adapter \
    --max_steps 500
```

### 4. Model Export & Ollama Integration
Once training completes, export the adapter and merge it for local inference:
```bash
# Merge the LoRA adapter into a GGUF file for Ollama
# (Add this logic to train_sre.py if you want automated export)
python -c "from unsloth import FastLanguageModel; \
model, tokenizer = FastLanguageModel.from_pretrained('./sre-kernel-adapter'); \
model.save_pretrained_gguf('sre-kernel-v1', tokenizer, quantization_method = 'q4_k_m')"

# Load into Ollama
ollama create sre-kernel -f Modelfile
```

---
*By training locally, you ensure that sensitive infrastructure data never leaves your environment.*
