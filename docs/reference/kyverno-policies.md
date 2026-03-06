# Reference: Zero-Trust Policy Governance (Kyverno) 🛡️

The AI4ALL-SRE Laboratory enforces strict operational boundaries using **Kyverno**. This ensures that even in an autonomous environment, all actions compliance with industrial security standards and infrastructure constraints.

---

## 🏛️ Policy Architecture

Policies are categorized by their enforcement mode: `Enforce` (blocks non-compliant actions) or `Audit` (logs violations). Our "Security-by-Default" stance prioritizes **Enforce** for all namespaces.

### 1. Resource Governance
To prevent "Noisy Neighbor" effects and resource exhaustion:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-requests-limits
spec:
  rules:
  - name: validate-resources
    match:
      any:
      - resources:
          kinds: ["Pod"]
    validate:
      message: "CPU and memory requests and limits are required."
      pattern:
        spec:
          containers:
          - resources:
              requests:
                cpu: "?*"
                memory: "?*"
              limits:
                cpu: "?*"
                memory: "?*"
```

### 2. Supply Chain Security
We prevent the deployment of untrusted or vulnerable code:
- **Image Verification**: Policies can be extended to verify Cosign signatures.
- **Vulnerability Gating**: Pods containing `CRITICAL` vulnerabilities (Trivy scans) are blocked at the admission gate.

---

## 🧠 AI Agent specific Constraints

The SRE AI Agent operates with elevated privileges but remains subject to policy-as-code guardrails.

| Constraint | Mechanism | Rationale |
| :--- | :--- | :--- |
| **No-Privileged-Escalation** | Kyverno `validate` | Prevents the agent from accidentally creating root-access containers. |
| **Label Enforcement** | Kyverno `validate` | The agent can only modify workloads tagged with `sre-intervention: "true"`. |
| **Automation Boundaries** | Kyverno `precondition` | Ensures the agent doesn't touch system namespaces (`kube-system`). |

---

## 📊 Compliance Monitoring

To audit policy hits and violations in real-time:

```bash
# Get a summary of all policy reports
kubectl get policyreports -A

# Inspect a specific violation
kubectl describe policyreport <report-name> -n <namespace>
```

*For technical implementation details, see `governance.tf` and the `/policies` directory.*

---
*Governance Lead: AI4ALL-SRE Laboratory*
