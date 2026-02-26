# Disaster Recovery Runbooks 🌋

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
2.  **Delete PVC**: (Warning: Data Loss) Delete the claim to trigger the local-path-provisioner to create a fresh volume.
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
*For environment re-builds from scratch, always use `./setup-all.sh`.*
