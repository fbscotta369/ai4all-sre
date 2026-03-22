"""
Unified RAG Interface for AI4ALL-SRE
Consolidates FAISS (ai_agent.py) and ChromaDB (rag_pipeline.py) implementations.
Supports fallback chain: ChromaDB → FAISS → In-memory
"""

import os
import abc
import hashlib
import datetime
from typing import List, Dict, Optional, Any
from dataclasses import dataclass
from loguru import logger


@dataclass
class RAGResult:
    """Standardized RAG query result"""

    rank: int
    similarity: float
    content: str
    metadata: Dict[str, Any]
    excerpt: str


class BaseRAGBackend(abc.ABC):
    """Abstract base class for RAG backends"""

    @abc.abstractmethod
    def embed_document(
        self, content: str, doc_id: str, metadata: Dict[str, Any]
    ) -> bool:
        """Embed a document into the vector store"""
        pass

    @abc.abstractmethod
    def query(self, text: str, n_results: int = 3) -> List[RAGResult]:
        """Query for similar documents"""
        pass

    @abc.abstractmethod
    def is_available(self) -> bool:
        """Check if backend is available and initialized"""
        pass

    @abc.abstractmethod
    def get_document_count(self) -> int:
        """Get number of documents in the store"""
        pass


class ChromaDBBackend(BaseRAGBackend):
    """ChromaDB implementation with MinIO persistence"""

    def __init__(self):
        self.client = None
        self.collection = None
        self._available = False

        try:
            import chromadb
            from chromadb.utils import embedding_functions

            host = os.getenv("CHROMA_HOST", "chromadb.observability.svc.cluster.local")
            port = int(os.getenv("CHROMA_PORT", "8000"))
            embed_model = os.getenv("EMBED_MODEL", "all-MiniLM-L6-v2")

            self.client = chromadb.HttpClient(host=host, port=port)
            self.ef = embedding_functions.SentenceTransformerEmbeddingFunction(
                model_name=embed_model
            )
            self.collection = self.client.get_or_create_collection(
                name="post-mortems",
                embedding_function=self.ef,
                metadata={
                    "hnsw:space": "cosine",
                    "hnsw:construction_ef": 200,
                    "hnsw:M": 32,
                    "hnsw:search_ef": 100,
                    "hnsw:num_threads": 4,
                },
            )
            self._available = True
            logger.info(
                f"[+] ChromaDB backend initialized ({self.collection.count()} docs)"
            )

        except Exception as e:
            logger.warning(f"[!] ChromaDB unavailable: {e}")
            self._available = False

    def embed_document(
        self, content: str, doc_id: str, metadata: Dict[str, Any]
    ) -> bool:
        if not self._available:
            return False

        try:
            # Check for duplicates
            existing = self.collection.get(ids=[doc_id])
            if existing["ids"]:
                return False

            self.collection.add(ids=[doc_id], documents=[content], metadatas=[metadata])
            return True
        except Exception as e:
            logger.error(f"[!] ChromaDB embed error: {e}")
            return False

    def query(self, text: str, n_results: int = 3) -> List[RAGResult]:
        if not self._available:
            return []

        try:
            results = self.collection.query(
                query_texts=[text],
                n_results=n_results,
                include=["documents", "metadatas", "distances"],
            )

            hits = []
            for i, doc in enumerate(results["documents"][0]):
                hits.append(
                    RAGResult(
                        rank=i + 1,
                        similarity=1 - results["distances"][0][i],
                        content=doc,
                        metadata=results["metadatas"][0][i],
                        excerpt=doc[:500] + "..." if len(doc) > 500 else doc,
                    )
                )
            return hits

        except Exception as e:
            logger.error(f"[!] ChromaDB query error: {e}")
            return []

    def is_available(self) -> bool:
        return self._available

    def get_document_count(self) -> int:
        if not self._available:
            return 0
        return self.collection.count()


class FAISSBackend(BaseRAGBackend):
    """FAISS implementation with local persistence"""

    def __init__(self):
        self.index = None
        self.metadata = []
        self.embed_model = None
        self._available = False
        self._vector_dim = 384

        # Persistence paths
        self._persist_dir = os.path.join(
            os.path.dirname(__file__), "..", "..", "data", "vector_store"
        )
        self._index_file = os.path.join(self._persist_dir, "faiss_index.bin")
        self._metadata_file = os.path.join(self._persist_dir, "metadata.pkl")

        try:
            import faiss
            import numpy as np
            from sentence_transformers import SentenceTransformer
            import os
            import pickle

            self.embed_model = SentenceTransformer("all-MiniLM-L6-v2")
            self.np = np
            self.faiss = faiss
            self.pickle = pickle

            # Load existing index and metadata if available
            if os.path.exists(self._index_file) and os.path.exists(self._metadata_file):
                self.index = faiss.read_index(self._index_file)
                with open(self._metadata_file, "rb") as f:
                    self.metadata = pickle.load(f)
                logger.info(
                    f"[+] FAISS backend loaded from disk ({len(self.metadata)} entries)"
                )
            else:
                self.index = faiss.IndexHNSWFlat(self._vector_dim, 32)
                logger.info("[+] FAISS backend initialized (new)")

            # Ensure persist directory exists
            os.makedirs(self._persist_dir, exist_ok=True)
            self._available = True

        except Exception as e:
            logger.warning(f"[!] FAISS unavailable: {e}")
            self._available = False

    def embed_document(
        self, content: str, doc_id: str, metadata: Dict[str, Any]
    ) -> bool:
        if not self._available:
            return False

        try:
            # Check for duplicates by doc_id
            for existing_meta in self.metadata:
                if existing_meta.get("doc_id") == doc_id:
                    return False

            embedding = self.embed_model.encode([content])[0].astype("float32")
            self.index.add(self.np.array([embedding]))

            # Store metadata including content
            full_metadata = {"doc_id": doc_id, "content": content, **metadata}
            self.metadata.append(full_metadata)

            # Persist to disk
            self._persist()
            return True
        except Exception as e:
            logger.error(f"[!] FAISS embed error: {e}")
            return False

    def _persist(self):
        """Save index and metadata to disk."""
        try:
            self.faiss.write_index(self.index, self._index_file)
            with open(self._metadata_file, "wb") as f:
                self.pickle.dump(self.metadata, f)
        except Exception as e:
            logger.error(f"[!] FAISS persistence error: {e}")

    def query(self, text: str, n_results: int = 3) -> List[RAGResult]:
        if not self._available or self.index.ntotal == 0:
            return []

        try:
            query_vec = self.embed_model.encode([text])[0].astype("float32")
            distances, indices = self.index.search(
                self.np.array([query_vec]), n_results
            )

            hits = []
            for i, idx in enumerate(indices[0]):
                if idx != -1 and idx < len(self.metadata):
                    content = self.metadata[idx].get("content", "")
                    hits.append(
                        RAGResult(
                            rank=i + 1,
                            similarity=float(1 - distances[0][i]),
                            content=content,
                            metadata=self.metadata[idx],
                            excerpt=content[:500] + "..."
                            if len(content) > 500
                            else content,
                        )
                    )
            return hits

        except Exception as e:
            logger.error(f"[!] FAISS query error: {e}")
            return []

    def is_available(self) -> bool:
        return self._available

    def get_document_count(self) -> int:
        if not self._available:
            return 0
        return self.index.ntotal


class InMemoryBackend(BaseRAGBackend):
    """Simple in-memory fallback for when no vector store is available"""

    def __init__(self):
        self.documents = []
        self.embed_model = None
        self._available = True

        try:
            from sentence_transformers import SentenceTransformer
            import numpy as np

            self.embed_model = SentenceTransformer("all-MiniLM-L6-v2")
            self.np = np
        except:
            logger.warning("[!] SentenceTransformer unavailable, using simple matching")

    def embed_document(
        self, content: str, doc_id: str, metadata: Dict[str, Any]
    ) -> bool:
        # Check for duplicates
        for doc in self.documents:
            if doc["doc_id"] == doc_id:
                return False

        self.documents.append(
            {"doc_id": doc_id, "content": content, "metadata": metadata}
        )
        return True

    def query(self, text: str, n_results: int = 3) -> List[RAGResult]:
        if not self.documents:
            return []

        if self.embed_model:
            # Use semantic similarity
            try:
                query_vec = self.embed_model.encode([text])[0]
                scores = []

                for doc in self.documents:
                    doc_vec = self.embed_model.encode([doc["content"]])[0]
                    similarity = self.np.dot(query_vec, doc_vec) / (
                        self.np.linalg.norm(query_vec) * self.np.linalg.norm(doc_vec)
                    )
                    scores.append((similarity, doc))

                # Sort by similarity
                scores.sort(key=lambda x: x[0], reverse=True)

                hits = []
                for i, (similarity, doc) in enumerate(scores[:n_results]):
                    content = doc["content"]
                    hits.append(
                        RAGResult(
                            rank=i + 1,
                            similarity=float(similarity),
                            content=content,
                            metadata=doc["metadata"],
                            excerpt=content[:500] + "..."
                            if len(content) > 500
                            else content,
                        )
                    )
                return hits

            except Exception as e:
                logger.error(f"[!] InMemory semantic search error: {e}")

        # Fallback to simple keyword matching
        text_lower = text.lower()
        scored = []

        for doc in self.documents:
            content_lower = doc["content"].lower()
            # Simple word overlap score
            words = text_lower.split()
            score = sum(1 for word in words if word in content_lower) / max(
                len(words), 1
            )
            scored.append((score, doc))

        scored.sort(key=lambda x: x[0], reverse=True)

        hits = []
        for i, (score, doc) in enumerate(scored[:n_results]):
            content = doc["content"]
            hits.append(
                RAGResult(
                    rank=i + 1,
                    similarity=score,
                    content=content,
                    metadata=doc["metadata"],
                    excerpt=content[:500] + "..." if len(content) > 500 else content,
                )
            )
        return hits

    def is_available(self) -> bool:
        return self._available

    def get_document_count(self) -> int:
        return len(self.documents)


class UnifiedRAGPipeline:
    """
    Unified RAG pipeline with automatic fallback chain:
    1. ChromaDB (production, persistent)
    2. FAISS (local, high-performance)
    3. InMemory (fallback, always available)
    """

    def __init__(self):
        self.backends = [ChromaDBBackend(), FAISSBackend(), InMemoryBackend()]

        # Find first available backend
        self.primary_backend = None
        for backend in self.backends:
            if backend.is_available():
                self.primary_backend = backend
                break

        if self.primary_backend:
            logger.info(f"[+] RAG pipeline using {type(self.primary_backend).__name__}")
        else:
            logger.error("[!] No RAG backend available")

    def embed_post_mortem(
        self, content: str, alert_name: str, timestamp: str = None
    ) -> bool:
        """Embed a post-mortem document"""
        if not self.primary_backend:
            return False

        if timestamp is None:
            timestamp = datetime.datetime.utcnow().isoformat()

        doc_id = hashlib.sha256(content.encode()).hexdigest()[:16]
        metadata = {
            "alert_name": alert_name,
            "timestamp": timestamp,
            "embedded_at": datetime.datetime.utcnow().isoformat(),
        }

        return self.primary_backend.embed_document(content, doc_id, metadata)

    def query_similar_incidents(
        self, incident_description: str, n_results: int = 3
    ) -> List[RAGResult]:
        """Query for similar past incidents"""
        if not self.primary_backend:
            return []

        return self.primary_backend.query(incident_description, n_results)

    def format_context_for_llm(
        self, incident_description: str, n_results: int = 3
    ) -> str:
        """Format query results for LLM consumption"""
        hits = self.query_similar_incidents(incident_description, n_results)

        if not hits:
            return "No similar past incidents found in the post-mortem database."

        ctx = "## Similar Past Incidents (from Post-Mortem Database)\n\n"
        for hit in hits:
            ctx += f"### [{hit.rank}] {hit.metadata.get('alert_name', 'Unknown')} "
            ctx += f"(similarity: {hit.similarity:.2%})\n"
            ctx += f"{hit.excerpt}\n\n---\n\n"

        return ctx

    def get_stats(self) -> Dict[str, Any]:
        """Get pipeline statistics"""
        return {
            "primary_backend": type(self.primary_backend).__name__
            if self.primary_backend
            else None,
            "available_backends": [
                type(b).__name__ for b in self.backends if b.is_available()
            ],
            "document_count": self.primary_backend.get_document_count()
            if self.primary_backend
            else 0,
        }


# Singleton instance
_rag_pipeline = None


def get_rag_pipeline() -> UnifiedRAGPipeline:
    """Get or create the singleton RAG pipeline instance"""
    global _rag_pipeline
    if _rag_pipeline is None:
        _rag_pipeline = UnifiedRAGPipeline()
    return _rag_pipeline
