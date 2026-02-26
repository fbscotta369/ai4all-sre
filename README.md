# AI-Driven SRE Laboratory: Autonomous Resilience Control Plane 🚀

The **AI4ALL-SRE Laboratory** is an industrial-grade autonomous control plane designed for the next generation of AI-native workloads. It bridges the gap between raw telemetry and corrective action using a sophisticated **Multi-Agent System (MAS)**, ensuring machine-speed resilience for 2026-scale infrastructure.

---

## ⚡ Quick Start: Zero to Healthy in 5 Minutes

Experience the autonomous SRE lifecycle with a single command. This bootstraps the entire environment: K3s Cluster, Linkerd Mesh, Full Observability Stack (LGTM), and the AI Remediation Agent.

```bash
# 1. Clone and Initialize
git clone <your-repo-url> && cd ai4all-sre

# 2. Deployment (Everything Everywhere)
./setup-all.sh

# 3. Expose Dashboards
./start-dashboards.sh
```

> [!IMPORTANT]
> **Manual Steps Required**: To enable Slack notifications and fine-tune your incident policies, refer to the [Manual Configuration Guide](./docs/MANUAL_CONFIG.md).

---

## 🏗️ Core Technology Stack

The laboratory integrates Tier-1 technologies into a seamless resilience fabric.

| Component | Technology | Documentation |
| :--- | :--- | :--- |
| **Service Mesh** | Linkerd | [Official Docs](https://linkerd.io/) |
| **GitOps** | ArgoCD | [Official Docs](https://argoproj.github.io/cd/) |
| **Chaos Engine** | Chaos Mesh | [Official Docs](https://chaos-mesh.org/) |
| **Observability** | Prometheus / Grafana / Loki | [OSS Stack](https://prometheus.io/) |
| **Incident Management**| GoAlert | [Official Docs](https://goalert.org/) |
| **Policy Governance** | Kyverno | [Official Docs](https://kyverno.io/) |
| **Local Inference** | Ollama (Llama 3) | [GitHub](https://ollama.com/) |

---

## 💡 System Pillars

- **Intelligent Observability**: Automated log-to-context synthesis using specialized LLMs.
- **Agentic Remediation**: A Director LLM executing dynamic runbooks via non-idempotent M2M APIs.
- **Zero-Trust Resilience**: Cryptographic identity verification for every autonomous action via Linkerd.
- **Economic Efficiency**: Optimized for low-token consumption and local-first inference.

## 🕹️ Operational Pulse (The Internal Loop)
1.  **Adversary (Chaos Mesh)**: Injects cascading failure scenarios.
2.  **Observer (Prometheus/Loki)**: Detects anomalies and fires structured alerts.
3.  **Orchestrator (GoAlert)**: Aggregates alerts into Incidents and notifies the Agent.
4.  **Remediator (Autonomous Agent)**: Reaches consensus via MAS and executes `kubectl` fixes.

## 📂 Repository Navigation Map
- `ai-lab/fine-tuning/`: Official guide for locally fine-tuning the SRE-Kernel LLM on your GPU.
- `ai_agent.py`: The core Multi-Agent System reasoning engine.
- `chaos.tf`: Infrastructure-as-Code for 5+ failure experiments and workflows.
- `observability.tf`: Helm-based configuration for the full Grafana/Loki/Prom stack.
- `docs/`: In-depth guides for hardware, manual setup, and onboarding.
- `scripts/`: Operational automation and health-check validation.

---

*For technical specifications and C4 Models, see [ARCHITECTURE.md](./ARCHITECTURE.md).*
*For hardware requirements and environment optimization, see [docs/onboarding.md](./docs/onboarding.md).*
*For **Disaster Recovery** procedures, see [docs/RUNBOOKS.md](./docs/RUNBOOKS.md).*
*For **Governance Policies** (Kyverno), see [docs/POLICIES.md](./docs/POLICIES.md).*
*For **Root Cause Analysis** standards, see [docs/POST_MORTEM_TEMPLATE.md](./docs/POST_MORTEM_TEMPLATE.md).*
*For **Local AI Fine-Tuning** instructions, see [ai-lab/fine-tuning/README.md](./ai-lab/fine-tuning/README.md).*
*For **manual configuration** (Slack, GoAlert tuning), see [docs/MANUAL_CONFIG.md](./docs/MANUAL_CONFIG.md).*
