# Reference: System Architecture (C4 Model) 🏗️

This document defines the technical architecture of the AI4ALL-SRE Laboratory. It is structured according to the **C4 Model** and documents the boundaries of the control plane and data mesh.

---

## Core Design Principles

1.  **Local-First Autonomy**: All reasoning (LLM) and data storage happen within the laboratory perimeter to ensure 100% data sovereignty and low-latency decision loops.
2.  **M2M Zero-Trust**: Machine-to-Machine communication is cryptographically secured via Linkerd. No agent action is executed without a verified, mTLS-backed identity.
3.  **Consensus-Based Remediation**: Automated fixes require consensus from specialized domain agents (Network, DB, Compute) to prevent "Agentic Hallucination."
4.  **Audit-Ready Lineage**: Every automated action carries a global incident trace trace, allowing a direct mapping from a `kubectl` command back to the original telemetry anomaly.

---

## C4 Model - Level 1: System Context

The AI4ALL-SRE Laboratory operates as an autonomous enclave bridging the gap between raw telemetry and corrective action.

```mermaid
graph TD
    subgraph "External Constraints"
        GH["GitHub (Source of Truth)"]
    end

    subgraph "AI4ALL-SRE Ecosystem"
        CP["Autonomous Control Plane (K8s/Linkerd)"]
        Agent["Autonomous MAS (Multi-Agent System)"]
        Sink["Telemetry Sink (Loki/Prom/OTel)"]
    end

    subgraph "Hardware Plane"
        Inference["Local Inference Engine (Ollama/GPU)"]
    end

    GH -->|Desired State| CP
    CP -->|Telemetry| Sink
    Sink -->|Incident Context| Agent
    Agent -->|Remediation Request| CP
    Agent -->|Reasoning Request| Inference
    style CP fill:#f9f,stroke:#333,stroke-width:2px
    style Agent fill:#bbf,stroke:#333,stroke-width:2px
    style Sink fill:#bfb,stroke:#333,stroke-width:2px
```

---

## C4 Model - Level 2: Container (Data Mesh)

The system is a distributed **Data Mesh** where state is synchronized across asynchronous observers.

```mermaid
C4Container
    title Container diagram for AI4ALL-SRE Data Mesh

    Container_Ext(git, "GitHub", "Git", "Source of Truth")
    
    System_Boundary(c1, "K3s Cluster Envelope") {
        Container(argocd, "ArgoCD", "Go", "Syncs cluster state with Git")
        Container(apps, "Online Boutique", "Microservices", "Target application generating telemetry")
        ContainerDb(prom, "Prometheus", "TSDB", "Collects metrics")
        ContainerDb(loki, "Loki", "Log Store", "Collects indexed logs")
        Container(goalert, "GoAlert", "Go", "Incident Orchestration")
        Container(agent, "AI SRE Agent", "Python/FastAPI", "Autonomous Remediation")
    }
    
    Container(ollama, "Ollama", "C++", "Local LLM Inference Engine")

    Rel(git, argocd, "Webhook/Polling", "HTTPS")
    Rel(argocd, apps, "Deploys", "Kubernetes API")
    Rel(apps, prom, "Scrapes metrics", "HTTP")
    Rel(apps, loki, "Pushes logs", "HTTP")
    Rel(prom, goalert, "Fires alerts", "Webhook")
    Rel(goalert, agent, "Creates incident", "Webhook")
    Rel(agent, ollama, "Prompts", "REST API")
    Rel(agent, apps, "Remediates", "Kubernetes API")
```

---

## C4 Model - Level 3: Component (MAS Reasoning)

The Autonomous SRE Agent is composed of a **Multi-Agent System (MAS)** (see `observability.tf` configmaps).

```mermaid
C4Component
    title Component diagram for AI SRE Agent

    Container_Boundary(api, "AI SRE Agent API") {
        Component(webhook, "Webhook Receiver", "FastAPI", "Receives GoAlert payload")
        
        Boundary(mas, "Specialist Swarm") {
            Component(net, "Network Agent", "LLM Context", "Analyzes Linkerd/Ingress")
            Component(db, "Database Agent", "LLM Context", "Analyzes State/Storage")
            Component(comp, "Compute Agent", "LLM Context", "Analyzes CPU/Memory")
        }
        
        Component(director, "Director Agent", "Consensus Engine", "Synthesizes final action from Swarm")
        Component(guard, "Safety Guardrail", "Python logic", "Checks APF and Kyverno rules")
        Component(exec, "K8s Executor", "client-python", "Applies patches to API server")
    }

    Rel(webhook, mas, "Dispatches context")
    Rel(net, director, "Submits hypothesis")
    Rel(db, director, "Submits hypothesis")
    Rel(comp, director, "Submits hypothesis")
    Rel(director, guard, "Proposes remediation")
    Rel(guard, exec, "Approves action")
```

---

## Complete Alerting Chain (Sequence Diagram)

This diagram shows the end-to-end flow from failure injection to autonomous remediation.

```mermaid
sequenceDiagram
    autonumber
    participant C as Chaos Mesh (Adversary)
    participant A as Online Boutique (App)
    participant S as Telemetry Sink (Observer)
    participant G as GoAlert (Orchestrator)
    participant AG as AI SRE Agent (Remediator)

    C->>A: Trigger PodKill/Latency/CPU Stress
    A->>S: Metrics/Logs breach thresholds
    S->>G: Post Critical Alert (Webhook)
    G->>G: Create Incident & Escalation
    G->>AG: Dispatch Context via Webhook
    AG->>AG: MAS Consensus & Reasoning
    Note right of AG: Validating with Kyverno...
    AG->>A: Execute 'kubectl' Remediation
    A-->>AG: State Restored
```

---

## Failure Modes & Antifragility

### 1. LLM Saturation
- **Strategy**: Jittered Exponential Backoff.
- **Watchtower Mode**: If inference exceeds 60s, the Agent suspends write-actions and enters "Monitor-Only" state to prevent accidental cascading failures.

### 2. Mesh Partitioning
- **Strategy**: Linkerd proxy identity caching.
- **Result**: The Data Plane continues mTLS enforcement even if the Control Plane is temporarily unreachable.
