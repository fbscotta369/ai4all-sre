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

The laboratory follows a "One-Click" philosophy. If you have the prerequisites installed (Terraform, Helm, K3s, Ollama), run:

```bash
./setup-all.sh
```

### Post-Deployment Check (Success Verification)
Verify your laboratory integrity using the industrial validation suite:
```bash
./scripts/validate.sh
```

> [!TIP]
> **What's Next?**: After validation, head over to the [Manual Configuration Guide](./MANUAL_CONFIG.md) to enable external integrations like Slack.

---
*Document Version: 2.1.0 (Performance Tuning Edition)*
