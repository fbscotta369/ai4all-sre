# Tutorial: Quickstart & Deployment 🚀

This tutorial will take you from a blank workstation to a fully running Autonomous Resilience Control Plane (AI4ALL-SRE) in under 15 minutes.

**Goal:** Successfully deploy the K3s cluster, Linkerd mesh, Observability stack, and AI Agent.

---

## 1. Hardware & Environment Prep

### Hardware Tiers
1. **Developer**: 16GB RAM, 8-Core CPU (Exploring control plane).
2. **SRE Pro**: 32GB RAM, 16-Core CPU, RTX 3060+ (Full MAS residency).
3. **ML Researcher**: 128GB RAM, Ryzen 9, Dual RTX 4090 (Local fine-tuning).

### Linux (Native)
Optimized for Kubuntu 22.04+ or Fedora 38+.
You must increase your `inotify` limits for the Loki log scraper:
```bash
echo fs.inotify.max_user_instances=512 | sudo tee -a /etc/sysctl.conf
echo fs.inotify.max_user_watches=128000 | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Windows (WSL2)
Ensure you allocate enough memory in `%USERPROFILE%\.wslconfig`:
```ini
[wsl2]
memory=24GB
processors=8
```

---

## 2. Install Dependencies

If you are on a fresh system (Ubuntu/Debian), install the core tools (`kubectl`, `terraform`, `helm`, `docker`):

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

---

## 3. Deploy the Laboratory

Clone the repository and run the master setup script:

```bash
git clone https://github.com/fbscotta369/ai4all-sre.git && cd ai4all-sre

# The setup script will provision K3s, apply Terraform, and install ArgoCD
./setup.sh
```

### Verification
Run the comprehensive end-to-end testing script to guarantee all pods successfully initialized and HTTP services are responding with 200 OK statuses:
```bash
./e2e_test.sh
```

---

## 4. Access the Dashboards

We do not use publicly exposed NodePorts for security reasons. To access the control plane, run the dashboard port-forward script:

```bash
./start-dashboards.sh
```

You should see output similar to this:
```
✅ All dashboards and apps are now accessible!
------------------------------------------------
Online Boutique: http://localhost:8084
ArgoCD:          http://localhost:8080
Grafana:         http://localhost:8082
GoAlert:         http://localhost:8083 (or http://goalert.local)
Chaos Mesh:      http://localhost:2333 (or http://chaos.local)
------------------------------------------------
```

Congratulations! Your AI4ALL-SRE environment is now live.

> [!TIP]
> **Next Steps**: Now that the cluster is running, try breaking it! Head over to the [How-To Run Chaos Experiments](../how-to/run-chaos-experiments.md) guide.
