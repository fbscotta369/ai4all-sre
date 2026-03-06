# 🛠️ Command Reference: The Engineer's Toolbox
> **Tier-1 Operations Guide: v4.2.0**

This document provides a comprehensive list of commands for managing the AI4ALL-SRE Laboratory.

## 🚀 Lifecycle Management

| Command | Description | Risk Level |
| :--- | :--- | :--- |
| `./setup.sh` | Full environment bootstrap (K8s, TF, Argo). | 🟢 Low |
| `./cleanup.sh` | Soft cleanup of temporary resources/logs. | 🟢 Low |
| `./destroy.sh` | Complete teardown of all infrastructure. | 🔴 High |
| `./start-dashboards.sh` | Port-forward all Tier-1 dashboards (Grafana, Chaos, etc.). | 🟢 Low |

---

## 🤖 AI & Agent Operations

### Deployment
```bash
# Start the AI Agent via PM2 (Process Manager)
npx -y pm2 start ai_agent.py --name "ai-sre-agent" --interpreter python3
```

### Log Streaming
```bash
# Stream Agent logs from the cluster
kubectl logs -l app=ai-agent -n observability -f
```

---

## 🧪 Testing & Validation

### Full Validation Suite
```bash
# Run the standardized validation script
./scripts/validate.sh
```

### Python Unit Tests
```bash
# Run all unit tests
python3 -m unittest discover tests/
```

### Manual Health Checks
```bash
# Verify Linkerd Mesh Health
linkerd check

# Verify ArgoCD Sync Status
argocd app list
```

---

## 🛡️ Security & Secret Management

### Vault Access
```bash
# Get the Vault root token (for lab use only)
kubectl get secret vault-unseal-keys -n vault -o jsonpath='{.data.vault-root}' | base64 --decode
```

### PKI / Certificate Verification
```bash
# Check validity of internal mTLS certs
openssl x509 -in issuer.crt -text -noout
```

---

## 🌪️ Chaos Engineering

### Quick Injection (Network Delay)
```bash
kubectl apply -f chaos/network-delay.yaml
```

### Chaos Mesh Token Extraction
```bash
kubectl get secret chaos-mesh-token -n default -o jsonpath='{.data.token}' | base64 --decode
```

---
*Senior SRE: AI4ALL-SRE Operations*
