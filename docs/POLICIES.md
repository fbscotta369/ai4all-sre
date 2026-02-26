# Zero-Trust Policy Governance: Kyverno 🛡️

The AI4ALL-SRE Laboratory enforces strict operational boundaries using **Kyverno**. This ensures that even in an autonomous environment, all actions (both human and agentic) comply with industrial security standards and infrastructure constraints.

## 🏛️ Policy Architecture

Policies are categorized by their enforcement mode: `Enforce` (blocks non-compliant actions) or `Audit` (logs violations but allows progress). In this lab, we prioritize **Enforce** for all critical production namespaces.

---

## 🔒 Active Security Policies

| Policy Name | Group/Kind | Target Action | Purpose |
| :--- | :--- | :--- | :--- |
| **Disallow Privileged** | `ClusterPolicy` | Block `privileged: true` | Prevents container escapes and unauthorized node access. |
| **Require Resource Limits**| `ClusterPolicy` | Validate `cpu`/`memory` limits | Prevents resource exhaustion (noisy neighbor effect). |
| **Auto-Mutate Limits** | `ClusterPolicy` | Inject default limits | Ensures baseline stability for microservices that miss resource tags. |

---

## 🤖 AI Agent Constraints

The SRE AI Agent operates within a specialized cryptographic context. Kyverno policies are specifically tuned to recognize the `sre-privileged-access: "true"` label.

1.  **Identity Verification**: The agent must present a valid ServiceAccount token and the correct mTLS identity via Linkerd.
2.  **Explicit Permission**: Only workloads labeled for AI intervention can be modified by the agent.
3.  **Kyverno Bypass?**: No. Even the high-privilege agent cannot bypass the "Disallow Privileged" policy, ensuring that an autonomous "hallucination" cannot escalate into a node-level compromise.

---

## 🛠️ Policy Enforcement Logs

To view policy violations or enforcement events in real-time:

```bash
# View ClusterPolicy status
kubectl get clusterpolicies

# Check for policy reports (audit/violations)
kubectl get policyreports -A
```

---
*For technical implementation details, see [governance.tf](../governance.tf).*
