# Architecture Specification: AI4ALL-SRE Autonomous Control Plane 🏗️

This document defines the high-fidelity technical architecture of the AI4ALL-SRE Laboratory. It is structured according to the **C4 Model** for architectural visualization and focuses on system resilience, data lineage, and failure mode antifragility.

---

## 🏛️ Core Design Principles

The laboratory is built on four architectural non-negotiables:

1.  **Local-First Autonomy**: All reasoning (LLM) and data storage happen within the laboratory perimeter to ensure 100% data sovereignty and low-latency decision loops.
2.  **M2M Zero-Trust**: Machine-to-Machine communication is cryptographically secured via Linkerd. No agent action is executed without an verified, mTLS-backed identity.
3.  **Consensus-Based Remediation**: Automated fixes require consensus from specialized domain agents (Network, DB, Compute) to prevent "Agentic Hallucination."
4.  **Audit-Ready Lineage**: Every automated action carries a global `Incident-UID`, allowing a direct trace from a `kubectl` command back to the original telemetry anomaly.

---

## 🗺️ C4 Model - Level 1: System Context

The AI4ALL-SRE Laboratory operates as an autonomous enclave that bridges the gap between raw telemetry and corrective action.

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

## 📦 C4 Model - Level 2: Container (Data Mesh)

The system is a distributed **Data Mesh** where state is synchronized across asynchronous observers.

- **Telemetry Sink**: Prometheus (Metrics) and Loki (Logs) managed as a unified observability fabric.
- **Messaging Hub**: Kubernetes API Server serving as the Global State Orchestrator.
- **Agent Memory**: FAISS-powered Vector Store for high-speed context retrieval and decision logging.

## 🧩 C4 Model - Level 3: Component (MAS Reasoning)

The Autonomous SRE Agent is composed of a **Multi-Agent System (MAS)**:
1.  **Context Collector**: Aggregates logs, metrics, and K8s events into a unified Trace-bound context.
2.  **Specialist Swarm**: Domain-specific agents (`NetworkAgent`, `DatabaseAgent`, `ComputeAgent`) analyze the context simultaneously.
3.  **Director Agent (Consensus Engine)**: Synthesizes specialist output to determine the true Root Cause and optimal action.
4.  **Executor**: Validates actions against Kyverno policies and executes non-idempotent API calls.

---

## ⚡ Complete Alerting Chain (Sequence Diagram)

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

## 🛡️ Failure Modes & Antifragility

### 1. LLM Saturation
- **Strategy**: Jittered Exponential Backoff.
- **Watchtower Mode**: If inference exceeds 60s, the Agent suspends write-actions and enters "Monitor-Only" state to prevent accidental cascading failures.

### 2. Mesh Partitioning
- **Strategy**: Linkerd proxy identity caching.
- **Result**: The Data Plane continues mTLS enforcement even if the Control Plane is temporarily unreachable.

---
*Document Version: 3.1.0 (Enterprise Stability Edition)*
