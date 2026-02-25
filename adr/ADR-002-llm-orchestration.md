# ADR-002: LLM Orchestration & State Consistency Model

## Status
Accepted

## Context
The "Autonomous SRE Agent" requires a robust orchestration pattern to manage the lifecycle of an incident. We must decide how the agent interacts with the LLM (Llama 3) and how it maintains state during multi-step remediation (e.g., Scaling -> Verification -> Rollback).

## Decision
We have implemented a **Stateful Agentic Loop with a Global Relay Station (State Mesh)**. 

### Key Characteristics:
1.  **Orchestration Pattern**: Goal-Oriented Reasoning (ReAct) where the agent observes state, reasons (LLM), and acts (K8s API).
2.  **State Consistency**: Asynchronous consistency. The "Ground Truth" is the Kubernetes API. The Agent's local memory is used for "Intent Tracking" but is always validated against the Telemetry Sink (Prometheus/Loki) before execution.
3.  **Inference Model**: Local execution via Ollama to satisfy data sovereignty and low-latency requirements.

## Rationale
- **Idempotency**: By using the Kubernetes API as the root of state, we leverage its built-in idempotency. The agent doesn't need to manage complex state transitions; it simply requests a "Desired State".
- **Resilience**: A "Stateful Loop" allows the agent to handle transient network failures or pod restarts by re-reading the Telemetry Sink upon initialization.
- **Backpressure Handling**: The relay station pattern allows us to implement Jittered Exponential Backoff at the orchestrator layer if the LLM becomes saturated.

## Alternatives Considered
- **Stateless Webhooks**: Rejected because multi-step remediation (e.g., Analysis -> Scale -> verify) requires a persistent context that webhooks cannot provide without an external database.
- **Actor-Model (Ray/Orleans)**: Strong for extreme scale but introduces unnecessary infrastructure complexity for the current laboratory scope.

## Consequences
- **Memory Pressure**: The agent must manage its local Vector Memory (ADR-001) carefully to avoid context-window saturation.
- **Race Conditions**: In a multi-agent environment, we must implement "Locking" or "Leader Election" to prevent conflicting remediations on the same resource.
