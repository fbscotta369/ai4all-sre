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

## 📚 Documentation & Resource Index

| Category | Resource | Description |
| :--- | :--- | :--- |
| **Architecture** | [ARCHITECTURE.md](./ARCHITECTURE.md) | Technical specifications and C4 Model diagrams. |
| **Governance** | [docs/POLICIES.md](./docs/POLICIES.md) | Kyverno-enforced security and Zero-Trust boundaries. |
| **Ops & Recovery**| [docs/RUNBOOKS.md](./docs/RUNBOOKS.md) | Disaster recovery and incident stabilization procedures. |
| **Reporting** | [docs/POST_MORTEM_TEMPLATE.md](./docs/POST_MORTEM_TEMPLATE.md) | Standardized RCA format for AI Agent vector memory. |
| **Setup** | [docs/onboarding.md](./docs/onboarding.md) | Hardware requirements and environment optimization. |
| **Configuration** | [docs/MANUAL_CONFIG.md](./docs/MANUAL_CONFIG.md) | Manual tuning (Slack, GoAlert) and external integrations. |
| **AI Laboratory** | [ai-lab/fine-tuning/README.md](./ai-lab/fine-tuning/README.md) | Official guide for local LLM fine-tuning on consumer GPUs. |

---
*Document Version: 2.2.0 (Autonomous Resilience Edition)*
