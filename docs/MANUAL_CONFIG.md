# Manual Configuration & External Integrations 📖

This guide provides step-by-step instructions for external integrations and manual fine-tuning not covered by the automated Terraform bootstrap.

---

## 🔗 Slack Integration (Enterprise Alerts)

To receive real-time autonomous remediation logs and critical incidents in Slack, follow these steps to generate a Webhook URL:

### 1. Create a Slack App
1.  Visit the [Slack API: App Management](https://api.slack.com/apps) portal.
2.  Click **Create New App** -> **From scratch**.
3.  Name your app (e.g., `SRE-Agent-Lab`) and select your workspace.

### 2. Enable Incoming Webhooks
1.  In the app settings sidebar, select **Incoming Webhooks**.
2.  Toggle **Activate Incoming Webhooks** to **On**.
3.  Click **Add New Webhook to Workspace**.
4.  Select the channel (e.g., `#alerts`) and click **Allow**.

### 3. Configure the Laboratory
1.  Copy the generated **Webhook URL**.
2.  Open `terraform.tfvars` in the project root.
3.  Add or update the following variable:
    ```hcl
    slack_api_url = "https://hooks.slack.com/services/T000.../B000.../XXXX..."
    ```
4.  Run `terraform apply` to synchronize the secret.

---

## 🚨 GoAlert Secondary Configuration

GoAlert is automatically seeded via a Kubernetes Job, but for advanced tuning (manual on-call schedules, custom rotations), follow these steps:

### Manual Database Access
If you need to query or patch the backend directly:
```bash
# Access the PostgreSQL terminal
kubectl exec -n incident-management -it goalert-db-postgresql-0 -- /bin/sh -c 'PGPASSWORD=goalertpass psql -U postgres -d postgres'
```

### Official Documentation
For sophisticated escalation patterns, refer to the [GoAlert User Guide](https://goalert.org/docs).

---

## 🔐 Dashboard Access Matrix

The laboratory provides two methods for accessing dashboards. **Ingress** is recommended for permanent setups, while **Port-Forwarding** is optimized for rapid local development.

| Service | Ingress URL | Local Port (via script) | Description |
| :--- | :--- | :--- | :--- |
| **ArgoCD** | `argocd.local` | 8080 | GitOps state and rollouts. |
| **Grafana** | `grafana.local` | 8082 | Global observability (OSS). |
| **GoAlert** | `goalert.local` | 8083 | Incident lifecycle manager. |
| **Chaos Mesh** | `chaos.local` | 2333 | Adversary failure injection. |
| **Online Boutique**| `boutique.local`| 8084 | The Target Microservices app. |

### Note on Ingress Resolution
To use `.local` addresses, add the following to your `/etc/hosts` file:
```text
127.0.0.1  argocd.local grafana.local goalert.local chaos.local boutique.local
```

---

## 🧪 Manual Chaos Workflows

While `chaos.tf` defines automated schedules, you can manually trigger high-impact failure scenarios:

```bash
# Trigger the 'Cascading Failure' workflow (sequential kill -> latency)
kubectl apply -f apps/chaos-experiments/disaster-workflow.yaml
```

*For more on failure types, see the [Chaos Mesh Docs](https://chaos-mesh.org/docs).*
