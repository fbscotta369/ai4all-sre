"""
AI4ALL-SRE: RAG Pipeline Foundation — Fix 12
Provides persistent post-mortem storage and semantic search for the AI Agent.

Architecture:
  Prometheus Alert → AI Agent → [Remediation + Post-Mortem]
                                      ↓
                              MinIO (S3) Persistence
                                      ↓
                              ChromaDB Embedding (sentence-transformers)
                                      ↓
                              RAG Query at next incident (context-aware RCA)

Usage:
  # Embed all existing post-mortems
  python3 rag_pipeline.py embed

  # Query for similar past incidents
  python3 rag_pipeline.py query "high memory usage paymentservice OOMKill"

  # Start the RAG server (REST API for the AI Agent)
  python3 rag_pipeline.py serve
"""

import os
import sys
import glob
import json
import datetime
import argparse
import hashlib

# Lazy imports — dependencies installed at container build time
try:
    import chromadb
    from chromadb.utils import embedding_functions

    CHROMA_AVAILABLE = True
except ImportError:
    CHROMA_AVAILABLE = False
    print(
        "[!] ChromaDB not installed. Run: pip install chromadb sentence-transformers",
        flush=True,
    )

try:
    import boto3
    from botocore.exceptions import ClientError

    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MINIO_ENDPOINT = os.getenv(
    "MINIO_ENDPOINT", "http://minio.minio.svc.cluster.local:9000"
)
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "ai4all-sre-post-mortems")
CHROMA_HOST = os.getenv("CHROMA_HOST", "chromadb.observability.svc.cluster.local")
CHROMA_PORT = int(os.getenv("CHROMA_PORT", "8000"))
POST_MORTEMS_DIR = os.getenv("POST_MORTEMS_DIR", "post-mortems")
EMBED_MODEL = os.getenv("EMBED_MODEL", "all-MiniLM-L6-v2")  # ~80MB, fast

# Validate required credentials
if not MINIO_ACCESS_KEY:
    raise ValueError("MINIO_ACCESS_KEY environment variable is required")
if not MINIO_SECRET_KEY:
    raise ValueError("MINIO_SECRET_KEY environment variable is required")


# ---------------------------------------------------------------------------
# MinIO: Persist post-mortems to S3-compatible storage (not ephemeral pod FS)
# ---------------------------------------------------------------------------
class PostMortemStore:
    """Persists post-mortem markdown files to MinIO."""

    def __init__(self):
        if not BOTO3_AVAILABLE:
            raise RuntimeError("boto3 not installed. Run: pip install boto3")
        self.s3 = boto3.client(
            "s3",
            endpoint_url=MINIO_ENDPOINT,
            aws_access_key_id=MINIO_ACCESS_KEY,
            aws_secret_access_key=MINIO_SECRET_KEY,
        )
        self._ensure_bucket()

    def _ensure_bucket(self):
        try:
            self.s3.head_bucket(Bucket=MINIO_BUCKET)
        except ClientError:
            self.s3.create_bucket(Bucket=MINIO_BUCKET)
            print(f"[+] Created MinIO bucket: {MINIO_BUCKET}", flush=True)

    def upload(self, local_path: str) -> str:
        """Upload a post-mortem markdown file to MinIO, return the S3 key."""
        filename = os.path.basename(local_path)
        # Partition by year/month for easy lifecycle management
        now = datetime.datetime.utcnow()
        key = f"{now.year}/{now.month:02d}/{filename}"
        self.s3.upload_file(local_path, MINIO_BUCKET, key)
        print(f"[+] Uploaded post-mortem → s3://{MINIO_BUCKET}/{key}", flush=True)
        return key

    def list_all(self) -> list[dict]:
        """List all post-mortems in the bucket."""
        paginator = self.s3.get_paginator("list_objects_v2")
        results = []
        for page in paginator.paginate(Bucket=MINIO_BUCKET):
            for obj in page.get("Contents", []):
                results.append(
                    {
                        "key": obj["Key"],
                        "size": obj["Size"],
                        "last_modified": str(obj["LastModified"]),
                    }
                )
        return results

    def download_all(self, dest_dir: str) -> list[str]:
        """Download all post-mortems to a local directory for embedding."""
        os.makedirs(dest_dir, exist_ok=True)
        paths = []
        for obj in self.list_all():
            local_path = os.path.join(dest_dir, os.path.basename(obj["key"]))
            self.s3.download_file(MINIO_BUCKET, obj["key"], local_path)
            paths.append(local_path)
        return paths


# ---------------------------------------------------------------------------
# ChromaDB: Semantic embedding and retrieval
# ---------------------------------------------------------------------------
class PostMortemVectorStore:
    """
    Embeds post-mortem documents into ChromaDB for semantic RAG retrieval.
    The AI Agent queries this store at incident time to retrieve similar
    past incidents and their resolutions, reducing hallucination in RCA.
    """

    COLLECTION = "post-mortems"

    def __init__(self):
        if not CHROMA_AVAILABLE:
            raise RuntimeError("chromadb not installed.")
        self.client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
        self.ef = embedding_functions.SentenceTransformerEmbeddingFunction(
            model_name=EMBED_MODEL
        )
        self.collection = self.client.get_or_create_collection(
            name=self.COLLECTION,
            embedding_function=self.ef,
            metadata={
                "hnsw:space": "cosine",
                "hnsw:construction_ef": 200,  # Higher accuracy during indexing
                "hnsw:M": 32,  # More connections for better recall
                "hnsw:search_ef": 100,  # Higher accuracy during query
                "hnsw:num_threads": 4,  # Parallel indexing
            },
        )
        print(
            f"[+] ChromaDB collection '{self.COLLECTION}' ready ({self.collection.count()} docs).",
            flush=True,
        )

    def embed_file(self, path: str) -> bool:
        """Embed a single post-mortem markdown file. Skip if already embedded."""
        with open(path, "r") as f:
            content = f.read()

        doc_id = hashlib.sha256(content.encode()).hexdigest()[:16]

        # Skip duplicates
        existing = self.collection.get(ids=[doc_id])
        if existing["ids"]:
            print(f"  [=] Already embedded: {os.path.basename(path)}", flush=True)
            return False

        filename = os.path.basename(path)
        # Extract alert name from filename convention: YYYYMMDD-HHMMSS-AlertName.md
        parts = filename.replace(".md", "").split("-", 2)
        alert_name = parts[2] if len(parts) >= 3 else filename

        self.collection.add(
            ids=[doc_id],
            documents=[content],
            metadatas=[
                {
                    "filename": filename,
                    "alert_name": alert_name,
                    "embedded_at": datetime.datetime.utcnow().isoformat(),
                }
            ],
        )
        print(f"  [+] Embedded: {filename}", flush=True)
        return True

    def embed_directory(self, directory: str):
        """Embed all .md files in a directory."""
        files = glob.glob(os.path.join(directory, "*.md"))
        print(
            f"[*] Embedding {len(files)} post-mortems from {directory}...", flush=True
        )
        new_count = sum(1 for f in files if self.embed_file(f))
        print(
            f"[+] Done. {new_count} new embeddings added. Total: {self.collection.count()}",
            flush=True,
        )

    def query(self, incident_description: str, n_results: int = 3) -> list[dict]:
        """
        Semantic search for past incidents similar to the given description.
        Returns the top-N most relevant post-mortems and their metadata.
        """
        results = self.collection.query(
            query_texts=[incident_description],
            n_results=n_results,
            include=["documents", "metadatas", "distances"],
        )
        hits = []
        for i, doc in enumerate(results["documents"][0]):
            hits.append(
                {
                    "rank": i + 1,
                    "distance": results["distances"][0][i],
                    "metadata": results["metadatas"][0][i],
                    "excerpt": doc[:500] + "..." if len(doc) > 500 else doc,
                }
            )
        return hits

    def format_context_for_llm(self, query: str, n_results: int = 3) -> str:
        """
        Returns a formatted string of past incidents for injection into the
        consensus LLM prompt, enabling context-aware, non-hallucinatory RCA.
        """
        hits = self.query(query, n_results)
        if not hits:
            return "No similar past incidents found in the post-mortem database."
        ctx = "## Similar Past Incidents (from Post-Mortem Database)\n\n"
        for hit in hits:
            ctx += f"### [{hit['rank']}] {hit['metadata']['alert_name']} (similarity: {1 - hit['distance']:.2%})\n"
            ctx += f"{hit['excerpt']}\n\n---\n\n"
        return ctx


# ---------------------------------------------------------------------------
# RAG Pipeline: Full ETL (MinIO → Local → ChromaDB)
# ---------------------------------------------------------------------------
def run_embed_pipeline():
    """Download all post-mortems from MinIO and embed into ChromaDB."""
    print("[*] Starting RAG Embed Pipeline...", flush=True)
    store = PostMortemStore()
    vector_store = PostMortemVectorStore()

    # Download from MinIO
    local_dir = "/tmp/rag-post-mortems"
    paths = store.download_all(local_dir)
    print(f"[*] Downloaded {len(paths)} post-mortems from MinIO.", flush=True)

    # Also include any local post-mortems not yet uploaded
    local_paths = glob.glob(os.path.join(POST_MORTEMS_DIR, "*.md"))
    for p in local_paths:
        store.upload(p)

    # Embed everything
    vector_store.embed_directory(local_dir)


def run_query(query: str):
    """Query the vector store for similar incidents."""
    vector_store = PostMortemVectorStore()
    hits = vector_store.query(query)
    print(f"\n📚 Top {len(hits)} similar incidents for: '{query}'\n", flush=True)
    for hit in hits:
        print(f"  [{hit['rank']}] {hit['metadata']['alert_name']}")
        print(f"       Similarity: {1 - hit['distance']:.2%}")
        print(f"       {hit['excerpt'][:200]}...\n")


def run_server():
    """Start a simple FastAPI endpoint for the AI Agent to query the RAG store."""
    try:
        from fastapi import FastAPI
        import uvicorn

        rag_app = FastAPI(title="AI4ALL-SRE RAG Server")
        vector_store = PostMortemVectorStore()

        @rag_app.get("/health")
        def health():
            return {"status": "ok", "total_embeddings": vector_store.collection.count()}

        @rag_app.get("/query")
        def query(q: str, n: int = 3):
            return {"results": vector_store.query(q, n)}

        @rag_app.get("/context")
        def context(q: str, n: int = 3):
            return {"context": vector_store.format_context_for_llm(q, n)}

        print("[*] RAG Server starting on :8001...", flush=True)
        uvicorn.run(rag_app, host="0.0.0.0", port=8001)
    except ImportError:
        print("[!] FastAPI/uvicorn not installed.", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AI4ALL-SRE RAG Pipeline")
    parser.add_argument(
        "command", choices=["embed", "query", "serve"], help="Pipeline command"
    )
    parser.add_argument(
        "query_text", nargs="?", default=None, help="Query text (for 'query' command)"
    )
    args = parser.parse_args()

    if args.command == "embed":
        run_embed_pipeline()
    elif args.command == "query":
        if not args.query_text:
            print("Error: provide a query string.")
            sys.exit(1)
        run_query(args.query_text)
    elif args.command == "serve":
        run_server()
