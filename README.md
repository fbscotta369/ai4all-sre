# AI4ALL-SRE Laboratory 🚀

The **AI4ALL-SRE Laboratory** is an industrial-grade autonomous control plane designed for the next generation of AI-native workloads. It bridges the gap between raw telemetry and corrective action using a sophisticated **Multi-Agent System (MAS)**, ensuring machine-speed resilience for 2026-scale infrastructure.

---

## 📚 Documentation (Diátaxis Framework)

Our documentation is structurally partitioned by user intent. Whether you need to learn, solve a specific problem, understand the architecture, or look up a reference, start here.

### 1. Tutorials (Learning-Oriented)
*Start here if you want to deploy the cluster from scratch or run an educational pipeline.*
- [**Quickstart:** Deploying the K3s Control Plane](./docs/tutorials/01-quickstart.md)
- [**AI Specialization:** Fine-Tuning the SRE-Kernel](./docs/tutorials/02-ai-model-finetuning.md)

### 2. How-To Guides (Problem-Oriented)
*Read these to perform specific, goal-directed tasks.*
- [**Chaos Engineering:** Triggering Disasters Safely](./docs/how-to/run-chaos-experiments.md)
- [**Integrations:** Configuring Slack & GoAlert](./docs/how-to/slack-and-goalert-integrations.md)

### 3. Reference (Information-Oriented)
*Technical specifications, boundaries, and historical incident instructions.*
- [**System Architecture:** C4 Model Boundaries](./docs/reference/system-architecture.md)
- [**Governance:** Kyverno Security Policies](./docs/reference/kyverno-policies.md)
- [**Disaster Recovery:** Infrastructure Runbooks](./docs/reference/incident-runbooks.md)

### 4. Explanation (Understanding-Oriented)
*High-level context on "Why" the system operates the way it does.*
- [**The Autonomous Loop:** MAS and Guardrails](./docs/explanation/the-autonomous-loop.md)
- [**Platform Engineering:** Zero-Touch Trace Correlation](./docs/explanation/zero-touch-trace-correlation.md)

---

## 🏗️ Core Technology Stack

The laboratory integrates Tier-1 technologies into a seamless resilience fabric.

| Component | Technology | Documentation |
| :--- | :--- | :--- |
| **Service Mesh** | Linkerd | [Official Docs](https://linkerd.io/) |
| **GitOps** | ArgoCD | [Official Docs](https://argoproj.github.io/cd/) |
| **Chaos Engine** | Chaos Mesh | [Official Docs](https://chaos-mesh.org/) |
| **Observability** | Prometheus / Grafana / Tempo | [OSS Stack](https://prometheus.io/) |
| **Incident Management**| GoAlert | [Official Docs](https://goalert.org/) |
| **Policy Governance** | Kyverno | [Official Docs](https://kyverno.io/) |
| **Local Inference** | Ollama (Llama 3) | [GitHub](https://ollama.com/) |

---
*Document Version: 4.0.0 (Tier-1 Diátaxis Edition)*
