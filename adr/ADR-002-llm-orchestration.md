# ADR-002: LLM Orchestration & State Consistency Model

## Status
Accepted

## Context
The "Autonomous SRE Agent" requires a robust orchestration pattern to manage the lifecycle of an incident. We must decide how the agent interacts with the LLM (Llama 3) and how it maintains state during multi-step remediation (e.g., Scaling -> Verification -> Rollback).

## Decision
We have implemented a **Stateful Agentic Loop with a Global Relay Station (State Mesh)** using a **Multi-Agent System (MAS)** with specialist agents.

### Key Characteristics:
1.  **Orchestration Pattern**: Goal-Oriented Reasoning (ReAct) where the agent observes state, reasons (LLM), and acts (K8s API).
2.  **Multi-Agent System**: Director Agent synthesizes consensus from specialist agents (Network, Database, Compute).
3.  **State Consistency**: Asynchronous consistency. The "Ground Truth" is the Kubernetes API. The Agent's local memory is used for "Intent Tracking" but is always validated against the Telemetry Sink (Prometheus/Loki) before execution.
4.  **Inference Model**: Local execution via Ollama to satisfy data sovereignty and low-latency requirements.
5.  **Debouncing**: Redis-backed distributed debounce prevents duplicate remediations for the same alert.

## Rationale
- **Idempotency**: By using the Kubernetes API as the root of state, we leverage its built-in idempotency. The agent doesn't need to manage complex state transitions; it simply requests a "Desired State".
- **Resilience**: A "Stateful Loop" allows the agent to handle transient network failures or pod restarts by re-reading the Telemetry Sink upon initialization.
- **Backpressure Handling**: Circuit breakers allow us to implement graceful degradation if the LLM becomes saturated.
- **Hallucination Mitigation**: Consensus among multiple specialist agents reduces the risk of destructive hallucinated commands.

## Circuit Breaker Configuration
| Dependency | fail_max | reset_timeout | Rationale |
|------------|----------|---------------|-----------|
| ollama | 3 | 120s | LLM inference may be slow to recover |
| redis | 5 | 30s | Fast recovery for state operations |
| k8s_api | 3 | 60s | Cluster API should recover quickly |
| git | 2 | 300s | Git operations require manual intervention |

## Consequences
- **Memory Pressure**: The agent must manage its local Vector Memory (ADR-001) carefully to avoid context-window saturation.
- **Race Conditions**: Redis debouncing prevents conflicting remediations on the same resource.
