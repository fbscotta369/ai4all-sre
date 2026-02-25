# Onboarding & Operational Setup 🛠️

This document covers the baseline requirements and "Getting Started" procedures for the AI4ALL-SRE Laboratory. 

## 📋 Prerequisites

### Hardware Optimization
For optimal performance (especially for Phase 6 Fine-Tuning):
- **OS**: Linux (Kubuntu 22.04 optimized) or Windows 11 with WSL2.
- **CPU**: Multi-core (Ryzen 9 5950X recommended).
- **RAM**: 32GB Minimum (128GB for local fine-tuning).
- **GPU**: NVIDIA RTX 3060 (12GB VRAM) or higher for local AI execution.

### Software Dependencies
- **Kubernetes**: k3s or similar lightweight distribution.
- **Terraform**: v1.5+ for Infrastructure-as-Code.
- **Helm**: v3+ for package management.
- **Ollama**: Local LLM runner for Llama 3 modules.

## 🚀 Deployment (One-Click Setup)

The laboratory is designed for rapid instantiation:

### 1. Initialize Infrastructure
```bash
# Deploys Cluster + Observability + Apps
./setup-all.sh
```

### 2. Expose Operational Dashboards
```bash
# Starts port-forwards for Grafana, Loki, and ArgoCD
./start-dashboards.sh
```

### 3. Continuous Validation
Run the local validation script to ensure all SRE layers (Zero Trust, APF, HPA) are healthy:
```bash
./scripts/validate.sh
```

## 📂 Project Structure
- `apps/`: Microservices manifests (Kustomize).
- `ai-lab/`: Local LLM fine-tuning scripts and templates.
- `adr/`: Architecture Decision Records (The "Why").
- `scripts/`: Operational automation and health-checks.
- `terraform/`: Multi-provider infrastructure definitions.

---
*For a deep-dive into system decisions and scaling patterns, refer to [ARCHITECTURE.md](../ARCHITECTURE.md).*
