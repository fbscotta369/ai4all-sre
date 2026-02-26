# Onboarding & System Optimization 🛠️

The AI4ALL-SRE Laboratory is a high-performance environment. This document ensures your underlying infrastructure is tuned for machine-speed autonomous operations.

---

## 📋 Hardware Specialization Tiers

Select the tier that matches your operational goals.

| Tier | Specifications | Use Case |
| :--- | :--- | :--- |
| **Developer** | 16GB RAM, 8-Core CPU | Exploring the control plane and running basic simulations. |
| **SRE Pro** | 32GB RAM, 16-Core CPU, RTX 3060+ | Full Multi-Agent (MAS) residency and high-concurrency chaos testing. |
| **ML Researcher**| 128GB RAM, Ryzen 9, Dual RTX 4090 | Local fine-tuning and massive-scale telemetry persistence. |

---

## 🐧 Environment Optimization

### Linux (Native)
Optimized for Kubuntu 22.04+ or Fedora 38+.
- **Inotify Limits**: Required for high-concurrency logging (Loki).
  ```bash
  echo fs.inotify.max_user_instances=512 | sudo tee -a /etc/sysctl.conf
  echo fs.inotify.max_user_watches=128000 | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  ```
- **GPU Acceleration**: Ensure `nvidia-container-toolkit` is installed for Ollama hardware acceleration.

### Windows (WSL2)
- **Memory Allocation**: Create/edit `%USERPROFILE%\.wslconfig`:
  ```ini
  [wsl2]
  memory=24GB
  processors=8
  ```
- **Networking**: Use `mirrored` networking mode in WSL2 for the most stable Ingress resolution.

---

## 🚀 Immediate Deployment

### 1. Unified Prerequisite Block (Kubuntu/Ubuntu/Debian)
If you are on a fresh system, run this once to install the core control plane tools (`kubectl`, `terraform`, `helm`, `docker`):

```bash
# Update and install dependencies
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Install Kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Helm
curl https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Final Install
sudo apt-get update && sudo apt-get install -y kubectl terraform helm docker.io
```

### 2. Deployment (Everything Everywhere)
# This will trigger the 'Prerequisites Doctor' if any tools are missing.
./setup-all.sh

### 3. AI Laboratory Setup (Optional)
If you plan to fine-tune your own models, run the specialized AI environment doctor:
```bash
./ai-lab/doctor.sh
```
*This handles GPU/CUDA verification and Conda environment bootstrapping.*

### Post-Deployment Check (Success Verification)
Verify your laboratory integrity using the industrial validation suite:
```bash
./scripts/validate.sh
```

> [!TIP]
> **What's Next?**: After validation, head over to the [Manual Configuration Guide](./MANUAL_CONFIG.md) to enable external integrations like Slack.

---
*Document Version: 2.1.0 (Performance Tuning Edition)*
