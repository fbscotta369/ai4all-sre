# ADR-001: Vector Storage for Agentic Memory

## Status
Accepted

## Context
The AI SRE Agent requires a "Contextual Memory" to store and retrieve historical Post-Mortems and cluster events. This memory enables the agent to perform comparative Root Cause Analysis (RCA)—identifying if a current failure matches a pattern from the past.

## Decision
We have implemented a **Unified RAG Pipeline with automatic fallback chain**: ChromaDB → FAISS → In-Memory. This provides both persistence and resilience.

## Rationale
- **Data Sovereignty**: Local storage ensures that sensitive infrastructure logs and incident details never leave the laboratory's security boundary.
- **Latency**: Sub-millisecond retrieval from local memory is critical during high-pressure incidents where cloud API round-trips (e.g., Pinecone) introduce unacceptable delay.
- **Resilience**: The fallback chain ensures the agent always has access to memory, even when preferred backends are unavailable.
- **Hardware Alignment**: FAISS HNSW indexing runs efficiently in-process without dedicated nodes.

## Backend Fallback Chain
1. **ChromaDB** (Primary): Disk-persistent via MinIO/S3, HNSW indexing
2. **FAISS** (Secondary): High-performance local HNSW index, sub-millisecond queries
3. **In-Memory** (Fallback): Zero-dependency mode for air-gapped operation

## Alternatives Considered
- **Pinecone**: Rejected due to PII/Data residency concerns and external dependency risk during cluster network isolation.
- **Milvus**: Rejected due to high resource overhead (requires dedicated nodes).
- **Qdrant**: Strong contender for future scale; retained in roadmap for multi-cluster federation.

## Consequences
- **Persistence**: ChromaDB provides persistent storage via MinIO; FAISS index can be saved/loaded from disk.
- **Scale**: HNSW indexing provides O(log n) search performance, handling 10k+ post-mortems efficiently.
- **Reliability**: The fallback chain ensures zero-downtime operation even when backends are unavailable.
