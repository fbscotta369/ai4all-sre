# ADR 0001: Choose Multi-Agent System (MAS) over Monolithic LLM Agent

## Status
Accepted

## Context
The AI4ALL-SRE system needs to analyze incidents across multiple domains (network, database, compute) to determine the root cause and appropriate remediation. A single LLM could be prompted to handle all domains, but this approach has limitations in terms of accuracy, hallucination risk, and cognitive load.

## Decision
We chose to implement a Multi-Agent System (MAS) with specialized agents for each domain (NetworkAgent, DatabaseAgent, ComputeAgent) and a Director Agent to synthesize their analyses and make a final decision.

## Consequences
### Positive
- **Domain Specialization**: Each agent can be optimized with domain-specific prompts and knowledge, improving accuracy.
- **Parallel Analysis**: Agents work concurrently, reducing mean-time-to-analysis.
- **Hallucination Mitigation**: By requiring consensus among specialists, we reduce the risk of destructive hallucinated commands.
- **Fault Tolerance**: Failure in one agent does not incapacitate the entire system.
- **Auditability**: Individual agent reasoning can be inspected separately.
- **Scalability**: Easy to add new specialist agents for emerging domains.

### Negative
- **Increased Complexity**: More components to develop, test, and maintain.
- **Higher Resource Usage**: Concurrent LLM inference increases peak resource demands.
- **Potential for Agent Disagreement**: Requires a robust Director Agent to resolve conflicts.

## Related Decisions
- ADR 0002: Choosing a Director Agent for consensus instead of simple voting.
- ADR 0003: Using structured output (Pydantic) to ensure valid agent responses.
