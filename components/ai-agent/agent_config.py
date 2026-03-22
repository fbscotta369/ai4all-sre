"""
Centralized configuration for AI Agent.
Loads configuration from environment variables with sensible defaults.
"""

import os
from typing import List, Optional
from pydantic import BaseModel
from loguru import logger


class DatabaseConfig(BaseModel):
    """Database configuration."""

    redis_url: str = os.getenv(
        "REDIS_URL", "redis://redis.observability.svc.cluster.local:6379/0"
    )
    alert_debounce_seconds: int = int(os.getenv("ALERT_DEBOUNCE_SECONDS", "120"))


class LLMConfig(BaseModel):
    """LLM configuration."""

    model: str = os.getenv("OLLAMA_MODEL", "sre-kernel")
    url: str = os.getenv(
        "OLLAMA_URL", "http://ollama.ollama.svc.cluster.local:11434/api/generate"
    )
    chat_url: str = os.getenv(
        "OLLAMA_CHAT_URL", "http://ollama.ollama.svc.cluster.local:11434/api/chat"
    )
    max_retries: int = int(os.getenv("OLLAMA_MAX_RETRIES", "3"))
    base_wait: float = float(os.getenv("OLLAMA_BASE_WAIT", "2.0"))
    timeout: int = int(os.getenv("OLLAMA_TIMEOUT", "120"))


class GitOpsConfig(BaseModel):
    """GitOps configuration."""

    mode: bool = os.getenv("GITOPS_MODE", "true").lower() == "true"
    manifests_base_dir: str = os.getenv("MANIFESTS_BASE_DIR", "apps/online-boutique")
    manifest_file: str = os.path.join(
        os.getenv("MANIFESTS_BASE_DIR", "apps/online-boutique"),
        "kubernetes-manifests.yaml",
    )
    git_repo_dir: str = os.getenv("GIT_REPO_DIR", "/workspace")
    git_remote: str = os.getenv("GIT_REMOTE", "origin")
    git_branch: str = os.getenv("GIT_BRANCH", "main")
    github_token: str = os.getenv("GITHUB_TOKEN", "")
    runbooks_dir: str = os.getenv("RUNBOOKS_DIR", "runbooks")
    post_mortems_dir: str = os.getenv("POST_MORTEMS_DIR", "post-mortems")


class SecurityConfig(BaseModel):
    """Security configuration."""

    safe_namespaces: List[str] = os.getenv("SAFE_NAMESPACES", "online-boutique").split(
        ","
    )
    forbidden_namespaces: set = {
        "kube-system",
        "kyverno",
        "linkerd",
        "vault",
        "cert-manager",
        "argocd",
    }
    max_replica_count: int = int(os.getenv("MAX_REPLICA_COUNT", "20"))


class VectorStoreConfig(BaseModel):
    """Vector store configuration."""

    embed_model: str = os.getenv("EMBED_MODEL", "all-MiniLM-L6-v2")
    vector_dim: int = int(os.getenv("VECTOR_DIM", "384"))
    hnsw_m: int = int(os.getenv("HNSW_M", "32"))
    persist_directory: str = os.getenv(
        "VECTOR_STORE_DIR",
        os.path.join(os.path.dirname(__file__), "..", "..", "data", "vector_store"),
    )


class AppConfig(BaseModel):
    """Main application configuration."""

    database: DatabaseConfig = DatabaseConfig()
    llm: LLMConfig = LLMConfig()
    gitops: GitOpsConfig = GitOpsConfig()
    security: SecurityConfig = SecurityConfig()
    vector_store: VectorStoreConfig = VectorStoreConfig()
    host: str = os.getenv("HOST", "0.0.0.0")
    port: int = int(os.getenv("PORT", "8000"))
    version: str = "5.0.0"


def validate_config(config: AppConfig) -> None:
    """Validate configuration for security and operational readiness."""
    if (
        config.database.redis_url
        == "redis://redis.observability.svc.cluster.local:6379/0"
    ):
        logger.warning("Using default Redis URL; ensure Redis is reachable.")
    if not config.gitops.github_token:
        logger.warning("GitHub token not set; Git push may fail.")
    if config.gitops.mode and not config.gitops.github_token:
        logger.error(
            "GitOps mode enabled but no GitHub token provided; push will fail."
        )
    # Add more checks as needed


# Global configuration instance
config = AppConfig()
validate_config(config)
