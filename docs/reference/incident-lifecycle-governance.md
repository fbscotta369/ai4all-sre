# Reference: Incident Lifecycle & Governance 🌋

Operational excellence in the AI4ALL-SRE Laboratory is defined by our **Blameless Culture** and our **Incident Lifecycle**. We treat every failure as an opportunity to improve the platform's autonomous reasoning.

---

## 🔁 The Lifecycle of an Incident

| Phase | Description | Key Actors |
| :--- | :--- | :--- |
| **Detection** | Prometheus alerts or SLO breaches detected by OTel. | Prometheus / OTel |
| **Notification** | Alerts aggregated in GoAlert and dispatched via Webhook. | GoAlert |
| **Analysis** | MAS Specialist swarm evaluates metrics, logs, and traces. | AI SRE Agent |
| **Consensus** | Director Agent synthesizes specialists into an Action Plan. | AI SRE Agent |
| **Remediation** | Patch applied to K8s API (validated by Kyverno). | Kubernetes API |
| **Verification** | Observability signals return to healthy baselines. | Grafana |
| **Review** | Generation of the automated Post-Mortem. | AI SRE Agent |

---

## 📝 Post-Mortem Culture

Every autonomous action generates a **Post-Mortem Report**. These reports are stored in the laboratory's audit trail and follow a strict "Lead SRE" format.

### Required Sections
1.  **Executive Summary**: High-level impact assessment (What broke and for how long?).
2.  **Telemetry Correlation**: Direct links to the PromQL queries and Tempo Spans used for analysis.
3.  **MAS Reasoning**: The internal "debate log" of the specialist agents (Why did we choose this fix?).
4.  **Remediation Payload**: The exact YAML patch applied to the cluster.
5.  **Next Steps**: Recommendations for infrastructure hardened (e.g., "Increase CPU limits" or "Add Network partition guardrail").

---

## ⚖️ Governance & Safety Guardrails

To prevent "Autonomous Runaway," the laboratory implements multiple levels of governance.

### Level 1: Semantic Guardrail
The agent is forbidden from executing destructive commands (e.g., `delete namespace`, `wipe pvc`) without explicit human intervention.

### Level 2: API Priority & Fairness (APF)
We use Kubernetes APF to ensure the AI Agent never starves the API server. Human operators always have "Super-Priority" to access the cluster and disable the agent if it exhibits irrational behavior.

### Level 3: Token Budgeting
The agent has a daily "Token Budget" for LLM inference. If the agent exceeds this budget, it enters a passive **Monitor-Only** state, preventing spiraling costs or infinite loops during catastrophic failures.

---
*Lead SRE: AI4ALL-SRE Laboratory*
