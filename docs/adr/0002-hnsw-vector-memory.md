# ADR 0002: Choose HNSW/FAISS for Vector Memory

## Status
Accepted

## Context
The AI4ALL-SRE system requires a vector store to store and retrieve historical post-mortems for Retrieval-Augmented Generation (RAG). The vector store must support fast similarity search to provide relevant context to the LLM during incident analysis.

## Decision
We chose to use Hierarchical Navigable Small World (HNSW) indexing via the FAISS library for our vector memory.

## Consequences
### Positive
- **Sub-millisecond Latency**: HNSW provides very fast similarity search, critical for real-time incident response.
- **Embedded Operation**: FAISS runs in-process, eliminating external service dependencies and reducing operational overhead.
- **Deterministic Performance**: Predictable latency characteristics without network variability.
- **Air-Gapped Capability**: Functions in completely isolated environments without internet access.
- **Battle-Tested**: FAISS is widely used and actively maintained by Facebook Research.

### Negative
- **Memory Resident**: The entire index must fit in RAM, limiting scalability to very large datasets.
- **Persistence Complexity**: Requires manual implementation of persistence (saving/loading index and metadata).
- **Limited Query Features**: Primarily designed for similarity search; lacks advanced querying capabilities of full vector databases.

## Alternatives Considered
- **External Vector Databases** (Pinecone, Weaviate, Qdrant): Offer horizontal scaling and managed services but introduce network latency, operational overhead, and security boundaries.
- **Hierarchical K-Means**: Simpler but generally worse recall/precision trade-off for high-dimensional embeddings.
- **Annoy**: Good performance but FAISS generally outperforms it, especially on GPU.
- **Brute Force/Linear Scan**: O(n) search complexity becomes prohibitive as the post-mortem library grows.

## Related Decisions
- ADR 0004: Choosing local-first LLM (Ollama) to maintain data sovereignty with the vector store.
