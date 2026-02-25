# ADR-001: Vector Storage for Agentic Memory

## Status
Accepted

## Context
The AI SRE Agent requires a "Contextual Memory" to store and retrieve historical Post-Mortems and cluster events. This memory enables the agent to perform comparative Root Cause Analysis (RCA)—identifying if a current failure matches a pattern from the past.

## Decision
We have selected **Local In-Memory Vectorization (using FAISS/Sentence-Transformers)** for the initial laboratory phase, with a roadmap toward **Qdrant** for persistent scale.

## Rationale
- **Data Sovereignty**: Local storage ensures that sensitive infrastructure logs and incident details never leave the laboratory's security boundary.
- **Latency**: Sub-millisecond retrieval from local memory is critical during high-pressure incidents where cloud API round-trips (e.g., Pinecone) introduce unacceptable delay.
- **Hardware Alignment**: Our desktop hardware (128GB RAM) allows for massive in-memory vector indexing without the need for a distributed database cluster.

## Alternatives Considered
- **Pinecone**: Rejected due to PII/Data residency concerns and external dependency risk during cluster network isolation.
- **Milvus**: Rejected for Phase 1 due to high resource overhead (requires dedicated nodes) which would detract from the microservices' resource pool.
- **ChromaDB**: Strong contender; retained as the primary alternative for transitioning to a disk-persistent local store.

## Consequences
- **Persistence**: Memory is ephemeral in the current prototype; restarting the agent requires re-indexing the `post-mortems/` directory.
- **Scale**: Linear search in local memory is efficient for <10k post-mortems but will require HNSW indexing (FAISS) as the laboratory matures.
