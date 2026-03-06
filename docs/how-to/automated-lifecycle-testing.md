# 🔄 How-To: Automated Lifecycle & E2E Testing
> **Tier-1 Engineering Standard: v4.2.0**

To ensure absolute confidence in the AI4ALL-SRE Laboratory's Infrastructure-as-Code (IaC) and runtime behavior, the project provides two core automation scripts: `e2e_test.sh` and `lifecycle_test.sh`.

This guide explains how to use these tools to validate the laboratory environment.

---

## 🧪 1. End-to-End Environment Validation (`e2e_test.sh`)

The `e2e_test.sh` script is a comprehensive "A-to-Z" test suite designed to be run against an *already running* AI4ALL-SRE cluster. 

Its primary purpose is to verify that the control plane, data mesh, and AI agents are not just "running" structurally, but actively answering requests.

### What it tests:
1. **Infrastructure**: Verifies K8s API connectivity and generic Node health.
2. **Workload Readiness**: Iterates through all core namespaces (ArgoCD, Vault, Chaos Mesh, Boutique, etc.) and uses `kubectl wait` to ensure all `Deployments`, `StatefulSets`, and `Rollouts` are in a `Ready`/`Available` state.
3. **Internal Data Mesh (Curl Testing)**: The script deploys an ephemeral Alpine `curl` pod inside the cluster. It then executes internal HTTP requests against the private DNS endpoints of every major service (for example: `http://frontend.online-boutique.svc.cluster.local`) and asserts that they return HTTP `200 OK` (or other expected states).
4. **Specific Features**: Evaluates Vault initialization logs and cronjob statuses.

### Execution:
```bash
cd /path/to/ai4all-sre
./e2e_test.sh
```

**Expected Result:** A color-coded terminal report detailing `PASS` or `FAIL` for 30+ system integration points.

---

## ♻️ 2. Zero-To-Hero Disaster Recovery (`lifecycle_test.sh`)

The `lifecycle_test.sh` script is the ultimate CI/CD reliability test. It proves that the entire AI4ALL-SRE ecosystem is 100% reproducible and ephemeral.

### The Lifecycle Flow:
1. **Phase 1: Total Destruction**: Executes `./destroy.sh -y`. This forcefully wipes the current Terraform state, forcefully deletes all namespaces, and scrubs lingering Custom Resource Definitions (CRDs). The cluster is left completely blank.
2. **Phase 2: Total Provisioning**: Executes `./setup.sh` in a non-interactive `headless` mode. ArgoCD spins up, Linkerd is bootstrapped, and the Data Mesh is constructed from zero.
3. **Phase 3: Validation**: Executes `./e2e_test.sh` exactly as described above to prove that the fresh environment is fully functional.
4. **Phase 4: Clean Slate (Optional)**: If passed the `--teardown` flag, it runs Phase 1 again to leave the cluster empty.

### Execution:
```bash
cd /path/to/ai4all-sre

# Run the lifecycle test, leaving the lab running at the end
./lifecycle_test.sh

# Run the lifecycle test, tearing down the lab at the end
./lifecycle_test.sh --teardown
```

> [!WARNING]
> Running this command **will destroy** any manual state, testing data, or ongoing experiments currently active in the cluster. Do not run this if you have unsaved data in the persistent volumes.

---
*QA & Reliability Engineering: AI4ALL-SRE Laboratory*
