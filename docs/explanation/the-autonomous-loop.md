# Explanation: The Autonomous Loop 🤖

To understand how the AI4ALL-SRE Laboratory functions without human intervention, one must understand the lifecycle of an alert. We use a **Consensus-over-Action** protocol to ensure machine-speed remediation without sacrificing systemic safety.

---

## The Lifecycle of Autonomous Remediation

The "Brain" of this whole project resides entirely within `ai_agent.py` (deployed in the `observability` namespace). Here is exactly what happens when chaos strikes:

### 1. The Webhook (`/webhook`)
Prometheus detects an anomaly (e.g., CPU is too high). It generates an alert payload and forwards it to GoAlert. GoAlert aggregates the incident and immediately issues an HTTP JSON Webhook to our Python script saying "Critical Alert: CPU is on fire!".

### 2. The Specialists (Multi-Agent System)
The Python script doesn't just ask one generic AI model. It instantiates three different "personas" (Specialist Agents) running concurrently against the LLM:
- **NetworkAgent**: "Is this a route flap or Ingress controller anomaly?"
- **DatabaseAgent**: "Is this a Postgres table lock or I/O bottleneck?"
- **ComputeAgent**: "Is this a memory leak or CPU exhaustion?"

### 3. The Director (Consensus)
The script collects the hypotheses from the three specialists and feeds them to a **Director AI**. The Director synthesizes the information and makes the final call: *"The ComputeAgent is correct; the CPU is saturated. We must scale up the frontend."*
> **Why a Multi-Agent System (MAS)?** Single LLMs are prone to hallucinating connections that don't exist. By forcing three domain experts to argue and a Director to vote, we mathematically reduce the probability of a destructive hallucinated command.

### 4. The Guardrail (Safety First)
Before the Python script touches the Kubernetes API, a hardcoded safety function (`is_action_safe`) intercepts the AI's output. Does the AI intend to delete something? Does it use `FORBIDDEN_KEYWORDS`? If yes, the script safely halts. 

### 5. API Priority and Fairness (APF)
An often-overlooked failure mode of Agentic AI is API saturation. If the AI enters a "Debate Loop" and spams the Kubernetes Server with hundreds of `kubectl` requests per second, it will organically DDoS the cluster.
By utilizing Kubernetes **API Priority and Fairness (APF)**, all traffic originating from the Agent's ServiceAccount is strictly throttled. If the AI panics, it gets placed in a low-priority queue, ensuring human operators can still access the cluster via `kubectl` to hit the kill-switch.

### 6. The Execution & Paper Trail
If all guardrails permit, the script executes the `PATCH` command against the API server. Simultaneously, the AI generates a `Post-Mortem` (a Markdown root-cause analysis report) and outputs the declarative YAML GitOps patch. This ensures the automated fix can be manually committed to the repository, making it permanent.
