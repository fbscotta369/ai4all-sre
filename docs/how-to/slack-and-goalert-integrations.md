# How-to Guide: Enterprise Event Routing (Slack & GoAlert) 🔗

This guide outlines the professional configuration for external notification channels and event sinks. We bridge the gap between cluster-internal observability and human-centric response systems.

---

## 🌩️ 1. Slack Enterprise Sink (Audit & Logic)

To maintain a searchable audit trail of autonomous remediations, we utilize the Slack Webhook API.

### Identity & Secret Governance
1.  **Slack App Creation**: Visit the [Slack API Portal](https://api.slack.com/apps) and create a "SRE Agent Lab" application.
2.  **Secret Management**: Avoid hardcoding URLs. We store the webhook in Terraform and inject it as a Kubernetes Secret.
    ```bash
    # Update terraform.tfvars
    slack_webhook_url = "https://hooks.slack.com/services/T000/B000/XXXX"
    ```
3.  **Namespace Isolation**: The secret is scoped strictly to the `observability` namespace and is only accessible by the `ai-agent` service account.

### Operational Verification
1.  Navigate to the `#sre-alerts` channel.
2.  Verify the message footprint: Look for the `Trace-Link` and `Post-Mortem` URLs in the remediation logs.

---

## 🚑 2. GoAlert: High-Availability Incident Management

GoAlert acts as the mission-critical switchboard for on-call rotations and escalation logic.

### Automated Provisioning (GitOps)
The laboratory uses the `configure_goalert_v2.py` script to ensure the following are provisioned out-of-the-box:
- **Rotations**: Weekly SRE on-call rotations linked to the "Admin" team.
- **Escalation Policies**: 2-step escalation (Schedule -> Direct Page) with 5-minute jittered delays.
- **Integration Keys**: Prometheus AlertManager v2 generic integration keys.

### Manual Overrides & Break-Glass
In the event of a configuration drift, use the dashboard:
- **URL**: `http://localhost:8083` (Standard) or `http://goalert.local` (Ingress)
- **RBAC**: Access is controlled via basic auth in the laboratory, but should be integrated with OIDC (e.g., Dex/Okta) in production.

### Direct Backend Access
For deep troubleshooting or mass-patching rotations:
```bash
kubectl exec -n incident-management -it goalert-db-postgresql-0 -- /bin/sh -c 'PGPASSWORD=goalertpass psql -U postgres -d postgres'
```

---

## 🛡️ 3. Security Best Practices
- **Webhook Rotation**: Slack tokens should be rotated every 90 days via the Terraform module.
- **mTLS Enforcement**: Communication from AlertManager to GoAlert is proxied through the Linkerd service mesh, ensuring encryption in transit even across namespaces.
- **Rate Limiting**: We implement ingress rate-limiting for the GoAlert API to prevent "Alert Storm" DDoS attacks during cascading failures.

---
*Platform Engineering: AI4ALL-SRE Laboratory*
