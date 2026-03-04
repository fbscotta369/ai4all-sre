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

## 🛡️ Tier-1 Industrial Features

This laboratory implements elite engineering standards for mission-critical reliability:

*   **Zero-Trust Networking**: Explicit Linkerd authorization policies (Server/Auth) instead of "default allow."
*   **Security Governance**: Kyverno-based Admission Control that blocks images with CRITICAL vulnerabilities (sourced from real-time Trivy scans).
*   **Advanced CI/CD**: Hardened GitHub Actions with Multi-Language Linting, CodeQL (SAST), Secret Scanning (Gitleaks), and Automated SBOM (CycloneDX) generation.
*   **Modern Deployment**: Argo Canary Rollouts with automated, metrics-driven rollback logic for the frontend.
*   **FinOps Control**: Strict `ResourceQuotas` and `LimitRanges` to model industrial cost governance and prevent resource exhaustion.
*   **Incident Hyper-Correlation**: One-click "Alert-to-Trace" integration linking Prometheus with Tempo for sub-second MTTR.

---

## 🏗️ Core Technology Stack

The laboratory integrates Tier-1 technologies into a seamless resilience fabric.

| Component | Technology | Documentation |
| :--- | :--- | :--- |
| **Service Mesh** | Linkerd (Zero-Trust) | [Official Docs](https://linkerd.io/) |
| **GitOps** | ArgoCD + Rollouts | [Official Docs](https://argoproj.github.io/cd/) |
| **Chaos Engine** | Chaos Mesh | [Official Docs](https://chaos-mesh.org/) |
| **Observability** | OTel / Prom / Grafana / Tempo | [OSS Stack](https://prometheus.io/) |
| **Incident Management**| GoAlert + Slack | [Official Docs](https://goalert.org/) |
| **Policy Governance** | Kyverno (Admission Control) | [Official Docs](https://kyverno.io/) |
| **SRE Agent Security** | Gitleaks / CodeQL | [Security Center](https://github.com/features/security) |
| **Local Inference** | Ollama (Llama 3) | [GitHub](https://ollama.com/) |

---
*Document Version: 4.0.0 (Tier-1 Diátaxis Edition)*

> [!CAUTION]
> **Maintenance**: To completely wipe the laboratory infrastructure (including all namespaces and Terraform resources), run `./destroy.sh`. To recreate it, run `./setup-all.sh`.
