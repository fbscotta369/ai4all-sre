# 🤖 AI4ALL-SRE: The Autonomous Engineering Laboratory
> **Tier-1 Technical Documentation: v4.2.0**

[![SRE: Tier-1](https://img.shields.io/badge/SRE-Tier--1-blue.svg)](https://google.github.io/sre/)
[![DevSecOps: Hardened](https://img.shields.io/badge/DevSecOps-Hardened-green.svg)](https://www.devsecops.org/)
[![AI: Agentic](https://img.shields.io/badge/AI-Agentic-orange.svg)](https://ollama.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

AI4ALL-SRE is an enterprise-grade laboratory and **Internal Developer Platform (IDP)** for researching the intersection of SRE, DevSecOps, and Autonomous AI Agents.

### 🆕 New in v5.0.0
- **🧠 Contextual Memory**: HNSW-indexed vector memory for historical incident RAG.
- **🚀 Dynamic Scaling**: Just-in-time node provisioning via Karpenter integration.
- **🛡️ Enhanced VDP**: Standardized security disclosure program (RFC 9116).

---

## 🏗️ Architecture & Philosophy

The system is built on a **Zero-Trust Data Mesh** and an **Autonomous Multi-Agent System (MAS)**.

```mermaid
graph TD
    subgraph "SRE CI/CD"
        GA["GitHub Actions"]
    end

    subgraph "Autonomous Cluster"
        CP["Control Plane (K8s)"]
        Mesh["Linkerd Zero-Trust"]
        MAS["AI Specialist Swarm"]
    end

    subgraph "Local HW"
        GPU["Ollama (Llama 3)"]
    end

    GA -->|GitOps| CP
    CP -->|Telemetry| MAS
    MAS -->|Inference| GPU
    MAS -->|Remediation| CP
    style CP fill:#1a1a1a,stroke:#4a4a4a,color:#fff
    style MAS fill:#2a2a2a,stroke:#6a6a6a,color:#fff
```

- **Local-First AI**: Specialized "SRE-Kernels" running on local GPUs via Ollama.
- **Zero-Trust Mesh**: mTLS and Authorization at every hop via Linkerd.
- **GitOps Core**: Infrastructure and application state managed via Terraform and ArgoCD.
- **Autonomous Loop**: A feedback-driven system that Detects, Analyzes, and Remediates in < 120s.

---

## 📂 Documentation Structure (Diátaxis Alignment)

Our documentation hub is designed for professional engineering onboarding.

| Category | Description | Key Documents |
| :--- | :--- | :--- |
| **🚀 Tutorials** | Guided onboarding for new engineers. | [Quickstart Guide](docs/tutorials/01-quickstart.md) |
| **🛠️ How-To** | Practical SOPs for operational tasks. | [Disaster Recovery](docs/how-to/disaster-recovery-dry-runs.md) |
| **🏗️ Reference** | Technical specifications and C4 models. | [System Architecture](docs/reference/system-architecture.md) |
| **🧠 Explanation** | Deep-dives into our engineering philosophy. | [Platform Manifesto](docs/explanation/platform-engineering-manifesto.md) |

---

## ⚡ Quickstart: The Golden Path

```bash
# 1. Initialize the Hardware & Cluster Plane
./setup.sh

# 2. Deploy the AI SRE Agent
npx -y pm2 start ai_agent.py --interpreter python3

# 3. Trigger a Chaos Experiment
kubectl apply -f chaos/network-delay.yaml
```

---

## 🧪 Operational Validation & Testing

The platform maintains a high standard of reliability through an extensive unit and integration testing suite.

```bash
# Provide a 100% reproducible zero-to-hero lifecycle (Destroy -> Setup -> Verify)
./lifecycle_test.sh

# Run the comprehensive A-to-Z End-to-End Test Suite against live endpoints
./e2e_test.sh

# Run specialized Python unit tests
python3 -m unittest discover tests/
```

- **Lifecycle reproducibility**: `lifecycle_test.sh` proves that the entire infrastructure and data mesh can be fully destroyed and rebuilt from scratch and validated autonomously.
- **Specialized AI Tests**: Validates MAS Consensus, Safety Guardrails, and Remediation Edge Cases.
- **Infrastructure Validation**: Terraform linting and security scanning (Trivy/TFSec).
- **Operational Scripts**: Unit tests for GoAlert configuration, cert generation, and load generators.

---

## 🛡️ Security & Compliance

The laboratory implements strict **Governance-as-Code**:
- **Kyverno**: Admission gaurdrails blocking CVE-exposed images.
- **Linkerd**: Mandatory mTLS for all machine-to-machine traffic.
- **CodeQL**: Automated security scanning of the autonomous agent logic.

---

## 👥 Meet the Specialist Swarm

The **Autonomous MAS** consists of specialized agents that collaborate on incident resolution:
- 🌐 **Network Specialist**: Linkerd/Traffic Analysis.
- 💾 **Database Specialist**: State & Storage Integrity.
- ⚙️ **Compute Specialist**: CPU/Memory profiling.
- 🎬 **Director Agent**: Consensus and Execution Engine.

---
*Engineering Lead: AI4ALL-SRE Platform*
