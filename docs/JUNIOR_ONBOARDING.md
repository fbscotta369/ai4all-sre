# 🎓 AI4ALL-SRE: The Junior Engineer's Onboarding Guide

Welcome to the team! 🎉 

If you're reading this, you've inherited a codebase that sounds like science fiction: an **Autonomous Resilience Control Plane**. You'll see words like "Zero-Trust", "LLM Inference", "Multi-Agent System", and "Antifragility" thrown around a lot.

Don't panic. Behind the buzzwords, this is just a very smart script that reads logs and runs `kubectl` commands so humans don't have to wake up at 3:00 AM. 

This guide is separated from the main architectural docs specifically for you. It translates the "Staff Engineer" jargon into plain English.

---

## 1. The 30-Second Elevator Pitch

Imagine you run an online store (`online-boutique`). Suddenly, the shopping cart service crashes.
1. **Old Way (Painful)**: An alarm rings. A tired engineer wakes up, logs into a VPN, opens a dashboard, reads the logs, finds the error, and types a command to restart the cart service. Time taken: 20 minutes.
2. **Our Way (Awesome)**: An alarm triggers. Our Python script (`ai_agent.py`) intercepts the alarm, asks a local AI model (Llama 3 via Ollama) "Hey, what does this error mean?". The AI says "The cart service is out of memory, you should restart it." The Python script checks if it's safe to do so, and automatically restarts it. Time taken: 15 seconds.

## 2. Demystifying the Tech Stack (The "What" and "Why")

We use a lot of tools. Here is why we need them, in simple terms:

| Tool | "Fancy" Name | Plain English Translation |
| :--- | :--- | :--- |
| **Terraform** | Infrastructure as Code (IaC) | A script that rents the computers and sets up the base network. (Look in `main.tf`, `observability.tf`).<br><br>**Why Terraform?** We use Terraform for "Day 0" setup (creating the cluster, namespaces, and installing base charts like Prometheus). Why not use just scripts? Because Terraform is *declarative*—it remembers what it built (in a state file) and only changes what's strictly necessary. |
| **ArgoCD** | GitOps Orchestrator | A robot that constantly looks at our GitHub repo. If the code in GitHub changes, ArgoCD automatically pushes those changes to the live server.<br><br>**Why ArgoCD over Jenkins/GitHub Actions?** Traditional CI/CD pushes code *to* the cluster. ArgoCD sits *inside* the cluster and pulls code *from* GitHub. If someone manually deletes a deployment, ArgoCD instantly notices the cluster doesn't match Git and heals it. Git is the single source of truth. |
| **Prometheus** | Telemetry / Observability | A specialized database that just records numbers over time (e.g., "CPU is at 80% at 9:00 AM, 85% at 9:01 AM"). |
| **Loki** | Log Aggregation | A massive text file search engine for every single `print()` statement our apps make. |
| **Linkerd** | Service Mesh (Zero-Trust) | A super-secure post office. Every time *Service A* talks to *Service B*, Linkerd wraps the message in a secure envelope (mTLS) to prove who sent it.<br><br>**Why Linkerd and not Istio?** Istio is powerful but notoriously heavy and complex. Linkerd is written in Rust, consumes barely any memory, and enforces our Zero-Trust architecture (cryptographic identity for every pod) out-of-the-box without weeks of configuration. |
| **Chaos Mesh** | Chaos Engineering | A gremlin we willingly invited into our system to break things on purpose, just to test if our AI reacts fast enough. |
| **Ollama** | Local Inference Engine | A program that lets us run ChatGPT-like AI brains directly on our own computers, so we don't have to pay OpenAI or leak private logs to the internet.<br><br>**Why Local LLMs instead of OpenAI/Claude?** Two reasons: Latency and Data Privacy. During a massive system outage, waiting 5 seconds for a remote API call is too slow. Furthermore, our internal logs contain sensitive company data that legally cannot leave our secure cluster. |
| **Kyverno** | Policy / Governance | The bouncer at the club. Even if the AI tries to run a dangerous command (like deleting the whole database), Kyverno blocks the request at the door.<br><br>**Why Kyverno over OPA Gatekeeper?** Kyverno is Kubernetes-native. Instead of writing complex policies in a specialized language like Rego, we write policies in standard YAML, which is much easier for Junior engineers to learn and maintain. |

---

## 3. How the AI Agent Actually Works (Under the Hood)

The "Brain" of this whole project lives in one file: `ai_agent.py` (inside the `observability` namespace). 

Here is exactly what that file does when an alarm goes off:

1. **The Webhook (`/webhook`)**: Prometheus notices the CPU is too high. It sends a JSON message (a Webhook) to our Python script saying "Alert: CPU is on fire!".
2. **The Specialists (Multi-Agent System)**: The Python script doesn't just ask one AI. It asks three different "personas":
   - **NetworkAgent**: "Is this a router issue?"
   - **DatabaseAgent**: "Is this a database lock?"
   - **ComputeAgent**: "Is this a CPU/RAM issue?"
3. **The Director (Consensus)**: The script takes the answers from the 3 specialists and feeds them to a "Director" AI. The Director makes the final call: "The ComputeAgent is right, the CPU is dying. We need to scale up the frontend." 
   - *Why a Multi-Agent System?* Single AIs hallucinate (make things up). By forcing three domain experts to argue and a Director to vote, we mathematically reduce the chance of a hallucinated, destructive command.
4. **The Guardrail (Safety First)**: Before taking action, a simple Python `if` statement checks the AI's output. Does the AI want to delete something? (`FORBIDDEN_KEYWORDS`). If yes, the script stops. This prevents the AI from ruining the company.
   - *Architecture Note on APF*: We also use Kubernetes **API Priority and Fairness (APF)**. If the AI gets stuck in an infinite loop and starts spamming the Kubernetes server, the APF rules throttle the AI's traffic, ensuring human operators can still access the cluster.
5. **The Execution**: The script uses the official Kubernetes Python Library to patch the server, fixing the problem. 
6. **The Paper Trail (GitOps Patch)**: The AI generates a `Post-Mortem` (a report of what died and how it was fixed) and spits out the exact YAML code a human needs to save to GitHub to make the fix permanent.

---

## 4. Your Day 1 Checklist (Safe to Try!)

Want to get your hands dirty without breaking production? Do this:

1. **Open the Dashboards**: Run `./start-dashboards.sh`. Look at Grafana. You'll see the "Error Budgets" and "Live Pod Logs".
2. **Trigger an Alarm Safely**: 
   - We have a "Predictive" alert set up. If you artificially spike the CPU, the AI will notice *before* it gets critically bad.
   - Look at `chaos.tf`. See the `frontend_cpu_spike`? That's our controlled chaos.
3. **Read an AI Post-Mortem**:
   - Once an alarm fires, the AI creates a MarkDown file. If you check the logs of the `ai-agent` pod (`kubectl logs -l app=ai-agent -n observability -f`), you will literally see the AI "thinking" out loud.

## 5. Things to Remember When Debugging

- **"The AI isn't doing anything!"** 
  - Check Ollama. Is the model loaded? `kubectl logs -l app=ollama -n default`.
  - Is the AI trapped by the APF (API Priority and Fairness) queue? If it spams the server, Kubernetes puts it in "Time Out".
- **"I changed a file manually on the server, but it reverted!"**
  - **ArgoCD did that.** ArgoCD is the boss. If you manually edit a file using `kubectl edit`, ArgoCD will notice it doesn't match GitHub and will overwrite your change. **Always commit your changes to GitHub.**
- **"The AI tried to fix it, but K8s said 'Forbidden'."**
  - That's Kyverno doing its job! Go look at `governance.tf`. You might be violating a security rule (like trying to run as a `privileged` root user).

---
*Welcome aboard. Operations is hard, but you've got an AI co-pilot now.* 🚀
