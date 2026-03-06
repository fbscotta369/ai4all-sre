# 🧠 MLOps: Standard Operating Procedures for Autonomous SRE
> **Tier-1 Engineering Standard: v4.2.0**

The AI4ALL-SRE Laboratory treats AI models like any other mission-critical microservice. This document outlines the **MLOps Pipeline** used for training, serving, and observing the "SRE-Kernel."

---

## 🏗️ The Training Lifecycle (Fine-Tuning)

We use a local-first fine-tuning pipeline to specialize General Purpose LLMs (like Llama 3) into domain-specific SRE experts.

### 1. Data Collection & Curation
- **Inputs**: Kubernetes audit logs, Prometheus alert history, and Linkerd trace data.
- **Synthetic Augmentation**: High-fidelity templates for resource saturation and GitOps drift are injected to improve minority-class performance.
- **Labeling**: Successful autonomous remediations are automatically promted for human-in-the-loop review before entering the next training corpus.

### 2. Specialization Infrastructure
The laboratory provides a dedicated hardware tier for local fine-tuning:
- **Optimization**: We utilize **Unsloth** for 2x faster, 70% lower memory fine-tuning using 4-bit LoRA adapters.
- **Format**: Models are exported in **GGUF (q4_k_m)** format for sub-second inference latency on Ollama.

### 3. Model Evaluation & Benchmarking
Before promotion, every model must pass the **SRE-Kernel Evaluation Suite**:
- **Simulated Precision**: % of correctly identified root causes in chaos-driven test sets. Target: > 92%.
- **Command Recall**: % of successfully generated and valid `kubectl` commands. Target: > 98%.
- **Hallucination Scoring**: Measured using the safety guardrail failure logs. Target: < 1%.

---

## 🚀 Serving & Orchestration (Ollama)

Models are served via a hardened **Ollama** deployment within the cluster.

- **Resource Governance**: Pods are confined by `ResourceQuotas` and `PriorityClasses` to ensure inference SLA is maintained during cluster-wide incidents.
- **API Priority**: The AI Agent's requests are assigned to a high-priority queue to ensure sub-second remediation consensus.

---

## 📊 Model Observability: Reasoning Sanity

We track more than just hardware metrics. We track the **Reasoning Health** of the agent swarms.

| Metric | Purpose | Monitoring Tool |
| :--- | :--- | :--- |
| **Tokens/Sec** | Throughput efficiency per model instance. | Grafana |
| **Consensus Ratio** | Level of agreement between Specialist Agents. | Prometheus |
| **RCA Error Rate** | Frequency of rejected commands by the Safety Guardrail. | Loki |
| **Reasoning Drift** | Deviation from established post-mortem patterns. | SRE-Eval |

---

## 🔄 Continuous Improvement (Feedback Loop)

Every autonomous remediation includes a feedback cycle:
- **Human-in-the-Loop**: SREs "Upvote" or "Downvote" the generated Post-Mortem reports in GitOps.
- **Offline DPO**: Downvoted actions are used as negative preference examples for future training cycles.

---
*MLOps Architect: AI4ALL-SRE Laboratory*
