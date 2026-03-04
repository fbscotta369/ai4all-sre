# How-to Guide: Slack & GoAlert Integrations 🔗

This guide provides step-by-step instructions for manually configuring external notification channels that are not handled by the automated Terraform bootstrap.

**Goal:** Configure Slack and GoAlert for human-in-the-loop notification routing.

---

## 1. Implement Slack Enterprise Alerts

To receive real-time autonomous remediation logs and critical incidents in a Slack channel, you must generate an Incoming Webhook URL.

### Create a Slack App
1.  Visit the [Slack API: App Management](https://api.slack.com/apps) portal.
2.  Click **Create New App** -> **From scratch**.
3.  Name your app (e.g., `SRE-Agent-Lab`) and select your workspace.

### Enable Incoming Webhooks
1.  In the app settings sidebar, select **Incoming Webhooks**.
2.  Toggle **Activate Incoming Webhooks** to **On**.
3.  Click **Add New Webhook to Workspace**.
4.  Select the channel (e.g., `#alerts`) and click **Allow**.

### Configure the Laboratory
1.  Copy the generated **Webhook URL**.
2.  Open `terraform.tfvars` in the project root.
3.  Add or update the following variable:
    ```hcl
    slack_api_url = "https://hooks.slack.com/services/T000.../B000.../XXXX..."
    ```
4.  Apply the changes to synchronize the secret into the cluster:
    ```bash
    terraform apply
    ```

---

## 2. GoAlert Secondary Configuration

GoAlert is automatically seeded via a Kubernetes Job (which configures the Prometheus integration API key and Escallation Policies). For advanced tuning like manual on-call schedules or custom rotations, handle configuration via the UI or direct Database access.

### Dashboard Access
1. Start the Port Forwards: `./start-dashboards.sh`
2. Access GoAlert at `http://localhost:8083`
3. Default Credentials:
   * **User**: `admin`
   * **Password**: `admin123`

### Manual Database Access (Break-Glass)
If you need to query or patch the backend directly:
```bash
# Access the PostgreSQL terminal interactively
kubectl exec -n incident-management -it goalert-db-postgresql-0 -- /bin/sh -c 'PGPASSWORD=goalertpass psql -U postgres -d postgres'
```

For highly sophisticated escalation patterns, refer to the [GoAlert User Guide](https://goalert.org/docs).
