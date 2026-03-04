# Reference: Disaster Recovery Runbooks 🌋

Operational procedures for restoring the AI4ALL-SRE Laboratory in the event of major infrastructure failure or state corruption.

---

## 🌩️ Scenario 1: Total GitOps (ArgoCD) Failure
**Symptom**: The ArgoCD UI is unreachable and application workloads (`online-boutique`) are drifting or disappearing.

1.  **Manual Reconciliation**: If the controller is dead, revert to manual Helm/Kubectl:
    ```bash
    # Manually re-deploy ArgoCD CRDs
    kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=v2.10.4
    ```
2.  **State Re-Bootstrap**: Trigger a Terraform refresh to ensure the base provider still sees the cluster.
    ```bash
    terraform apply -target=helm_release.argocd
    ```

---

## 💾 Scenario 2: Persistent Volume (PV) Corruption
**Symptom**: Prometheus or Loki pods are stuck in `CrashLoopBackOff` with filesystem errors.

1.  **Stop the Workload**: Scale the deployment to 0.
    ```bash
    kubectl scale deployment/kube-prometheus-grafana -n observability --replicas=0
    ```
2.  **Delete PVC**: *(Warning: Data Loss)* Delete the claim to trigger the local-path-provisioner to create a fresh volume.
    ```bash
    kubectl delete pvc <pvc-name> -n observability
    ```
3.  **Restore**: Re-scale the deployment to 1.

---

## 🐳 Scenario 3: Container Runtime (K3s) Hang
**Symptom**: `kubectl` commands time out or pods are stuck in `Terminating`.

1.  **Cycle the Service**:
    ```bash
    sudo systemctl restart k3s
    ```
2.  **Verify Node Health**:
    ```bash
    kubectl get nodes
    ```

---

## 🧠 Scenario 4: AI Agent "Brain Freeze"
**Symptom**: The `ai-agent` pod is running but not processing alerts or logs.

1.  **Force Re-Read**: The agent loads its logic from a ConfigMap. If the logic is updated in Git, force a restart:
    ```bash
    kubectl rollout restart deployment/ai-agent -n observability
    ```
2.  **Clear Vector Memory**: If the agent is hallucinating based on old context:
    ```bash
    # (Optional) Clear the local FAISS cache if applicable (path-dependent)
    kubectl exec -it <ai-agent-pod> -n observability -- rm -rf /app/memory/*.index
    ```

---

## 🗑️ Scenario 5: Total State Corruption / Lab Reset
**Symptom**: The environment is in an inconsistent state (e.g., partial Terraform success, missing namespaces, or broken CRDs) and incremental fixes are failing.

1.  **Nuclear Clean**: Run the destructive cleanup script. This will forcefully purge namespaces, active chaos experiments, and local Terraform state locks.
    ```bash
    ./destroy.sh
    ```
    *Note: Type `yes` to confirm. This script is designed to be safe to run even if the environment is partially broken.*

2.  **Fresh Rebuild**: Once the cluster is clean, trigger the full bootstrap again.
    ```bash
    ./setup-all.sh
    ```

---
## 🔐 Scenario 6: Vault Sealed / Secret Access Denied
**Symptom**: Pods are stuck in `Init:0/1` or `CreateContainerConfigError`. Vault logs show `core: vault is sealed`.

1.  **Check Seal Status**:
    ```bash
    kubectl exec -it vault-0 -n vault -- vault status
    ```
2.  **Unseal (Lab Mode)**: In this local lab, Vault may auto-unseal if configured, otherwise use the unseal keys (see `/home/fb/.vault-keys` if persisted):
    ```bash
    kubectl exec -it vault-0 -n vault -- vault operator unseal <key>
    ```
3.  **Verify Kubernetes Auth**: Ensure the sidecar injector can talk to the Vault API:
    ```bash
    kubectl get pods -n vault -l app.kubernetes.io/name=vault-agent-injector
    ```

---
## 🛡️ Tier-1 Industrial Tip: Trace-First Debugging
Every critical alert in the laboratory is now **Trace-Linked**. When an incident fires in GoAlert or Slack, look for the `trace_link` annotation. Clicking this will take you directly to the Grafana Tempo query for the specific microservice and timeframe, significantly reducing Mean Time to Discovery (MTTD).

---
*For environment re-builds from scratch, always use `./setup-all.sh`.*
