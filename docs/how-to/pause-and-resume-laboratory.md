# How-to Guide: Pause and Resume the Laboratory ⏸️▶️

This guide explains how to pause and resume the AI4ALL-SRE laboratory to save compute resources when the lab is not in use.

---

## Overview

The pause/resume scripts allow you to:
- **Save compute resources** by scaling all workloads to zero
- **Preserve data** (PVCs, configs, and state are maintained)
- **Quickly restore** the lab to its previous state

This is especially useful for:
- Running the lab on low-end hardware (e.g., laptops with limited GPU)
- Saving cloud compute costs when the lab is not needed
- Switching between different projects without full teardown

---

## Prerequisites

- `kubectl` configured with access to the cluster
- Bash shell (Linux, macOS, or WSL2)

---

## Pause the Laboratory

To pause all lab workloads and free up compute resources:

```bash
./scripts/pause.sh
```

The script will:
1. **Snapshot** current replica counts to `~/.ai4all-sre-pause-state.json`
2. **Cordon** all nodes to prevent rescheduling
3. **Scale down** all workloads (Deployments, StatefulSets, DaemonSets, Rollouts)
4. **Delete** running pods

### Namespaces Affected

The following namespaces are paused (kube-system is intentionally excluded):
- `online-boutique`
- `observability`
- `incident-management`
- `chaos-testing`
- `linkerd`
- `argocd`
- `argo-rollouts`
- `kyverno`
- `trivy-system`
- `vault`
- `minio`
- `ollama`
- `keda`
- `ai-lab`
- `docs-portal`

### Skip Confirmation

To skip the confirmation prompt:

```bash
./scripts/pause.sh -y
```

### What is Preserved

| Resource | Status |
|----------|--------|
| PersistentVolumeClaims (PVCs) | ✅ Preserved |
| ConfigMaps and Secrets | ✅ Preserved |
| Deployments/StatefulSets | ✅ Preserved (at 0 replicas) |
| Cluster nodes | Cordoned (no new pods scheduled) |

### What is Released

| Resource | Status |
|----------|--------|
| CPU allocations | Released |
| GPU resources | Released |
| Memory allocations | Released |
| Running pods | Terminated |

---

## Resume the Laboratory

To restore the lab to its previous state:

```bash
./scripts/resume.sh
```

The script will:
1. **Uncordon** all nodes
2. **Restore** workloads to their original replica counts
3. **Clean up** stale chaos resources

### Skip Confirmation

To skip the confirmation prompt:

```bash
./scripts/resume.sh -y
```

---

## State File

The pause script saves state to `~/.ai4all-sre-pause-state.json`:

```json
{
  "namespaces": {
    "observability": {
      "deployment/grafana": 1,
      "deployment/prometheus": 1,
      "statefulset/loki": 1
    },
    "online-boutique": {
      "deployment/frontend": 1,
      "deployment/cartservice": 2
    }
  }
}
```

> [!WARNING]
> If you delete the state file, you cannot restore the original replica counts. Workloads will be restored at their current (0) replica count.

---

## Troubleshooting

### Resume Fails with "No pause state found"

```bash
Error: No pause state found at ~/.ai4all-sre-pause-state.json
```

**Solution**: Run `./pause.sh` first to create the state file.

### Pods Not Starting After Resume

```bash
kubectl get pods -A | grep -v Running
```

**Possible causes**:
- Node resources are exhausted
- Image pull errors
- PVC attachment issues

**Solution**: Check pod events:
```bash
kubectl describe pod <pod-name> -n <namespace>
```

### State File Location

The state file is stored at `~/.ai4all-sre-pause-state.json`. To use a custom location:

```bash
STATE_FILE=/path/to/custom/state.json ./pause.sh
STATE_FILE=/path/to/custom/state.json ./resume.sh
```

---

## Use Cases

### Low-End Hardware

If you're running the lab on a laptop or desktop with limited GPU:

```bash
# Before shutting down for the day
./pause.sh -y

# When you return
./resume.sh -y
```

### Cost Optimization

To save cloud compute costs when the lab is not needed:

```bash
# End of day
./pause.sh -y

# Start of day
./resume.sh -y
```

### Project Switching

To switch between different projects without full teardown:

```bash
# Pause current lab
./pause.sh -y

# Work on other projects...

# Resume lab
./resume.sh -y
```

---

*Operational Engineering: AI4ALL-SRE Laboratory*
