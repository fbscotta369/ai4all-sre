# Tutorial: Industrial MLOps Pipeline (AI Specialization) 🧠

The AI4ALL-SRE Laboratory empowers you to transform a general-purpose LLM (Llama 3 8B) into a specialized **SRE-Kernel**. This document outlines the professional MLOps pipeline for Parameter-Efficient Fine-Tuning (QLoRA) using proprietary datasets within a local-first security perimeter.

---

## 🏗️ 1. Environmental Determinism

The specialization pipeline requires a deterministic environment to ensure reproducible weights.

### Hardware Prerequisites
- **GPU**: NVIDIA RTX 3060 (12GB) minimum; RTX 4090 recommended for 8-bit quantization.
- **Compute**: NVIDIA Container Toolkit must be configured for Docker/Containerd.

### Validation Script
Run the automated diagnostic suite to ensure your hardware mapping is correct:
```bash
./ai-lab/doctor.sh
```
> [!IMPORTANT]
> Ensure `NVML` and `CUDA` are reported as `[PASS]`. The kernel will automatically optimize its memory fallback strategy based on this report.

---

## 📊 2. Data Curation & Sovereignty

Our "Local-First" mission means no data leaves the laboratory perimeter during training.

### Dataset Schema
The training data resides in `ai-lab/fine-tuning/dataset.jsonl`. It contains specialized "Reasoning Spans" that map high-level alerts to specific GitOps and Kyverno constraints.
- **Instruct**: The SRE incident or request.
- **Context**: Live cluster state (e.g., `linkerd authz` outputs).
- **Response**: The verifiable remediation path.

---

## 🚀 3. The Specialization Pipeline

We utilize **Unsloth** for 2x faster, 70% lower memory fine-tuning. This allows for rapid iteration loops even on consumer-grade hardware.

### Triggering the Job
```bash
conda activate sre-ai-lab
./ai-lab/specialize-model.sh
```

### Pipeline Sequence
1.  **QLoRA Injection**: Injects low-rank adapters into the attention heads of the model.
2.  **Cross-Entropy Optimization**: Trains the model on our SRE-specific reasoning paths.
3.  **K-Means Quantization**: Once trained, the model is exported to GGUF format (typically `Q4_K_M` or `Q8_0`).
4.  **Ollama Manifest Generation**: Automatically creates a `Modelfile` and registers the `sre-kernel` with the local inference engine.

---

## 🧪 4. Model Verification & Benchmarking

Professional MLOps requires more than a simple "Hello World." We must verify **Instruction Adherence**.

### Ad-Hoc Reasoning Test
```bash
ollama run sre-kernel "Context: linkerd policy denied-by-default. Request: Fix cartservice communication to redis."
```

### Validation Metrics
Look for the following in the model's output:
- **Declarative Accuracy**: Does it propose specific `AuthorizationPolicy` YAML?
- **Governance Safety**: Does it mention Kyverno constraints?
- **Trace Context**: Does it reference the distributed tracing stack?

---

## 🔄 5. Continuous Improvement Loop

The **Autonomous Loop** relies on an iterative feedback mechanism.
- **Negative Examples**: Failed AI remediations are tagged and used for Refusal Training in the next cycle.
- **Post-Mortem Vectorization**: Successfully generated post-mortems are automatically added to the RAG (Retrieval-Augmented Generation) layer for zero-shot context.

---
*MLOps Lead: AI4ALL-SRE Laboratory*
