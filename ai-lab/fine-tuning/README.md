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

## 🏗️ Training Execution

Run the provided `train_sre.py` script:
```bash
python train_sre.py --dataset ./my_sre_data.jsonl --output ./sre-kernel-adapter
```

### What happens during training?
- **QLoRA**: The model is quantized to 4-bit to fit in your 12GB VRAM.
- **Gradient Checkpointing**: Reduces memory usage so you can use larger context windows.
- **Rank/Alpha**: We use a Rank of 16 to balance learning capacity and memory.

## 🤖 Deployment

Once training is complete, you can:
1.  **Merge**: Save the model as a a "Fixed" GGUF file for use in **Ollama**.
2.  **Inference**: Point your `ai_agent.py` to your new specialized model for higher-fidelity RCA.

---
*By training locally, you ensure that sensitive infrastructure data never leaves your environment.*
