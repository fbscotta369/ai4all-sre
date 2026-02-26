# Incident Post-Mortem Template 📝

Standardized format for Root Cause Analysis (RCA) reports. These reports are vectorized and stored in the AI Agent's long-term memory (FAISS) to prevent recurring outages.

---

## 📅 Summary Information

| Field | Details |
| :--- | :--- |
| **Incident Title** | *e.g., Frontend CPU Saturation Spike* |
| **Severity** | SEV1 (Critical) / SEV2 (High) / SEV3 (Minor) |
| **Date** | YYYY-MM-DD |
| **Duration** | HH:MM (Detect to Resolve) |
| **Affected Components** | *e.g., frontend-v2, product-catalog* |

---

## 🔍 Context & Detection
- **How was the incident detected?** (Alertmanager, Slack, manual observation)
- **Initial Symptoms**: Describe the observability metrics (e.g., 5xx errors > 5%, P99 Latency > 2s).

---

## 🛠️ Remediation Actions
Describe the steps taken to stabilize the system.
1.  **Immediate Mitigation**: (e.g., Scaling out replicas, rolling back a deployment).
2.  **AI involvement**: Did the `Director` agent intervene? What was its rationale?

---

## 📉 Impact Assessment
- **User Impact**: What percentage of users were affected?
- **Data Loss**: Was there any state inconsistency or data corruption?

---

## 🧬 Root Cause Analysis (RCA)
- **Primary Trigger**: Why did it happen? (e.g., Memory leak in v1.2.4, missing Kyverno limit).
- **The "5 Whys"**:
  1.  Why did the pod crash? -> Memory limit hit.
  2.  Why did it hit the limit? -> Unexpected traffic burst.
  3.  Why...

---

## 🛡️ Future Prevention (Antifragility)
- **Action Items**:
  - [ ] Update `governance.tf` with stricter limits.
  - [ ] Add a new chaos experiment to validate the fix.
  - [ ] Update MAS logic for better detection.

---
*Save this file as `post-mortems/YYYY-MM-DD-incident-title.md` to ensure the AI Agent processes it.*
