# How-to Guide: Run Chaos Experiments 🌪️

Chaos Engineering is how we prove our AI Agent works. Instead of waiting for a real outage, we intentionally break things to watch the system self-heal.

**Goal:** Execute a Chaos Mesh experiment and verify the autonomous healing process.

---

## Step 1: Access the Chaos Dashboard

1. Run the dashboard starter script: `./start-dashboards.sh`
2. Extract the Chaos Mesh login token exactly as follows:
   ```bash
   kubectl get secret chaos-mesh-token -n default -o jsonpath='{.data.token}' | base64 --decode
   ```
3. Open `http://localhost:2333` in your browser.
4. When prompted to login, click "Token" and paste the extracted string.

---

## Step 2: Triggering a Disaster

In the dashboard, navigate to **Schedules** or **Workflows** on the left menu. We have pre-configured Tier-1 Distributed Systems Failure Modes:
*   `az-route-flapping`: Simulates a complete Availability Zone network outage.
*   `split-brain-cart`: Severs the network between the frontend and the Redis cart database.
*   `redis-io-latency`: Injects severe disk read/write latency into the cart database.
*   `payment-time-skew`: Fast-forwards the clock on the payment service to break TLS tokens.

To manually trigger one immediately (bypassing the schedule timer):
1. Navigate to **Experiments** on the left menu.
2. Pause the active schedule.
3. Click the **Start** button on the experiment to inject the failure immediately.

---

## Step 3: Monitor Observability (The Symptoms)

Once Chaos is injected, open Grafana (`http://localhost:8082`):
- **SRE: SLO & Error Budgets**: Watch the Frontend Latency SLI plummet as the system starts failing.
- **SRE: Pod Log Search (Loki)**: You will see massive red error spikes as microservices start throwing HTTP 500s or timeouts.
- **SRE: Distributed Tracing (Tempo)**: Click the dynamically generated `TraceID` link in Loki to see the Tempo Waterfall graph. You will literally see exactly which spans are delaying the request (e.g., the exact network partition).

---

## Step 4: Verify the AI Agent's Response

While Grafana is showing the outage, verify the AI Agent is remediating the issue:
1. Open a new terminal and stream the agent logs:
   ```bash
   kubectl logs -l app=ai-agent -n observability -f
   ```
2. You will see the incoming `GoAlert` webhook payload containing the Prometheus alert.
3. You will see the **Specialist Agents** (Network, Database, Compute) debating the root cause in real-time.
4. Finally, you will see the **Director Agent** execute the `RESTART` or `SCALE` command against the Kubernetes API server. 
5. Look back at Grafana—the Error Budget burn should stop as the pods are restored.
