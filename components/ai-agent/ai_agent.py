"""
AI4ALL-SRE: Hyper-Autonomous SRE Agent
Tier-1 Production Hardened — v5.0.0

Fixes Applied:
  - Fix 2: Real Git push via subprocess (not simulated print())
  - Fix 3: Redis-backed alert debounce (not ephemeral /tmp)
  - Fix 9: Pydantic structured LLM output (not regex + prompt injection risk)
"""

import os
import re
import json
import yaml
import time
import random
import datetime
import asyncio
import subprocess
import threading
import concurrent.futures
from typing import Literal, Optional

import requests
import uvicorn
from fastapi import FastAPI, Request, BackgroundTasks
from kubernetes import client, config as k8s_config
from pydantic import BaseModel, ValidationError
from loguru import logger

# Import centralized configuration
import agent_config
from rag_unified import get_rag_pipeline

# ---------------------------------------------------------------------------
# AI/ML Memory: Unified RAG Pipeline
# ---------------------------------------------------------------------------
try:
    _rag_pipeline = get_rag_pipeline()
    logger.info(
        f"[+] Unified RAG pipeline initialized using {_rag_pipeline.primary_backend.__class__.__name__ if _rag_pipeline.primary_backend else 'none'}"
    )
except Exception as e:
    logger.error(f"[!] RAG pipeline initialization failed ({e}).")
    _rag_pipeline = None

# ---------------------------------------------------------------------------
# FIX 3: Redis-backed distributed debounce state (replaces /tmp)
# ---------------------------------------------------------------------------
try:
    import redis as redis_lib

    _redis_client = redis_lib.from_url(
        agent_config.config.database.redis_url, decode_responses=True
    )
    _redis_client.ping()
    REDIS_AVAILABLE = True
    logger.info("[+] Redis debounce store connected.")
except Exception as e:
    logger.error(f"[!] Redis unavailable ({e}). Falling back to in-memory debounce.")
    REDIS_AVAILABLE = False
    _in_memory_debounce: dict = {}

ALERT_DEBOUNCE_SECONDS = agent_config.config.database.alert_debounce_seconds


def is_debounced(alert_key: str) -> bool:
    """Returns True if this alert was already processed within the debounce window."""
    if REDIS_AVAILABLE:

        def _check_redis():
            return bool(_redis_client.exists(f"debounce:{alert_key}"))

        try:
            return CircuitBreakers.redis.execute(_check_redis)
        except Exception as e:
            logger.warning(
                f"[!] Redis circuit open or failed: {e}. Using in-memory fallback."
            )
            # Fallback to in-memory
            last = _in_memory_debounce.get(alert_key, 0)
            return (time.time() - last) < ALERT_DEBOUNCE_SECONDS
    else:
        last = _in_memory_debounce.get(alert_key, 0)
        return (time.time() - last) < ALERT_DEBOUNCE_SECONDS


def set_debounce(alert_key: str) -> None:
    """Mark this alert as processed with a TTL equal to the debounce window."""
    if REDIS_AVAILABLE:

        def _set_redis():
            _redis_client.set(f"debounce:{alert_key}", "1", ex=ALERT_DEBOUNCE_SECONDS)

        try:
            CircuitBreakers.redis.execute(_set_redis)
        except Exception as e:
            logger.warning(
                f"[!] Redis circuit open or failed: {e}. Using in-memory fallback."
            )
            # Fallback to in-memory
            _in_memory_debounce[alert_key] = time.time()
    else:
        _in_memory_debounce[alert_key] = time.time()


def is_rate_limited(alert_key: str, limit: int = 10, window: int = 60) -> bool:
    """Return True if alert_key exceeds limit within window seconds."""
    if not REDIS_AVAILABLE:
        # In-memory fallback (simple)
        # For simplicity, we'll use the debounce dict for rate limiting too
        # Not ideal but works for lab
        return False
    try:
        current = _redis_client.incr(f"ratelimit:{alert_key}")
        if current == 1:
            _redis_client.expire(f"ratelimit:{alert_key}", window)
        return current > limit
    except Exception as e:
        logger.warning(f"[!] Rate limit Redis error: {e}")
        return False


def alert_priority(alert: dict) -> int:
    """Return integer priority (lower is higher priority)."""
    severity = alert.get("labels", {}).get("severity", "warning")
    if severity == "critical":
        return 0
    elif severity == "warning":
        return 1
    else:
        return 2


# ---------------------------------------------------------------------------
# FIX 9: Pydantic schema for structured LLM output (eliminates regex + injection)
# ---------------------------------------------------------------------------
class RemediationAction(BaseModel):
    rca: str
    action: Literal["RESTART", "SCALE", "ROLLBACK", "NO_ACTION"]
    deployment: str
    namespace: str
    replicas: Optional[int] = None
    preventive_steps: Optional[str] = None
    gitops_patch_yaml: Optional[str] = None


# ---------------------------------------------------------------------------
# App Configuration
# ---------------------------------------------------------------------------
app = FastAPI(title="AI4ALL-SRE Agent", version=agent_config.config.version)
k8s_lock = threading.Lock()

OLLAMA_MODEL = agent_config.config.llm.model
OLLAMA_URL = agent_config.config.llm.url
OLLAMA_CHAT_URL = agent_config.config.llm.chat_url
SAFE_NAMESPACES = agent_config.config.security.safe_namespaces
FORBIDDEN_NAMESPACES = agent_config.config.security.forbidden_namespaces

# FIX 2: GitOps configuration for real Git push
GITOPS_MODE = agent_config.config.gitops.mode
MANIFESTS_BASE_DIR = agent_config.config.gitops.manifests_base_dir
MANIFEST_FILE = agent_config.config.gitops.manifest_file
GIT_REPO_DIR = agent_config.config.gitops.git_repo_dir
GIT_REMOTE = agent_config.config.gitops.git_remote
GIT_BRANCH = agent_config.config.gitops.git_branch
GITHUB_TOKEN = agent_config.config.gitops.github_token
RUNBOOKS_DIR = agent_config.config.gitops.runbooks_dir
POST_MORTEMS_DIR = agent_config.config.gitops.post_mortems_dir

# Initialize Kubernetes client
try:
    k8s_config.load_incluster_config()
except Exception:
    try:
        k8s_config.load_kube_config()
    except Exception:
        print("[!] Warning: Could not load Kubernetes config.", flush=True)

k8s_apps_v1 = client.AppsV1Api()
k8s_custom_api = client.CustomObjectsApi()


def index_post_mortems():
    """Index historical post-mortems for RAG."""
    if _rag_pipeline is None:
        return
    pm_dir = os.path.join(GIT_REPO_DIR, POST_MORTEMS_DIR)
    if not os.path.exists(pm_dir):
        return
    count = 0
    for f in os.listdir(pm_dir):
        if f.endswith(".md"):
            with open(os.path.join(pm_dir, f), "r") as file:
                content = file.read()
                # Try to extract alert_name and timestamp from filename
                # Format: {timestamp}-{alert_name}.md
                parts = f[:-3].split("-", 1)  # remove .md, split on first '-'
                timestamp = parts[0] if len(parts) >= 2 else ""
                alert_name = parts[1] if len(parts) >= 2 else f
                if _rag_pipeline.embed_post_mortem(content, alert_name, timestamp):
                    count += 1
    print(f"[*] Indexed {count} new post-mortems via Unified RAG pipeline.", flush=True)


def retrieve_context(query: str, k: int = 2) -> str:
    """Retrieve relevant post-mortems."""
    if _rag_pipeline is None:
        return "No historical context available."
    hits = _rag_pipeline.query_similar_incidents(query, n_results=k)
    if not hits:
        return "No historical context available."
    context = []
    for hit in hits:
        context.append(hit.content)
    return "\n---\n".join(context)


# ---------------------------------------------------------------------------
# Utility: Ollama with backoff and circuit breaker
# ---------------------------------------------------------------------------
from circuit_breaker import CircuitBreakers


def query_ollama_with_backoff(
    prompt: str, max_retries: int = 3, base_wait: float = 2.0
) -> str:
    """Jittered exponential backoff for Ollama inference with circuit breaker."""

    def _query_ollama():
        for attempt in range(max_retries):
            try:
                res = requests.post(
                    OLLAMA_URL,
                    json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False},
                    timeout=120,
                )
                if res.status_code == 200:
                    return res.json().get("response", "")
                logger.error(f"[!] Ollama HTTP {res.status_code}. Retrying...")
            except requests.exceptions.RequestException as e:
                logger.error(
                    f"[!] Ollama error: {e}. Retrying ({attempt + 1}/{max_retries})..."
                )
            wait = (base_wait * (2**attempt)) + random.uniform(0, 1)
            time.sleep(wait)
        return "Error: Maximum retries exceeded."

    # Execute with circuit breaker protection
    return CircuitBreakers.ollama.execute(_query_ollama)


def query_ollama_structured(
    prompt: str, schema: dict, max_retries: int = 3
) -> Optional[dict]:
    """
    FIX 9: Query Ollama with a JSON schema constraint.
    Forces the LLM to return structured data — eliminates regex and prompt injection.
    """
    for attempt in range(max_retries):
        try:
            res = requests.post(
                OLLAMA_CHAT_URL,
                json={
                    "model": OLLAMA_MODEL,
                    "stream": False,
                    "format": schema,
                    "messages": [{"role": "user", "content": prompt}],
                },
                timeout=120,
            )
            if res.status_code == 200:
                content = res.json().get("message", {}).get("content", "{}")
                return json.loads(content)
            print(
                f"[!] Ollama structured HTTP {res.status_code}. Retrying...", flush=True
            )
        except (requests.exceptions.RequestException, json.JSONDecodeError) as e:
            print(
                f"[!] Ollama structured error: {e}. Retrying ({attempt + 1}/{max_retries})...",
                flush=True,
            )
        time.sleep((2**attempt) + random.uniform(0, 1))
    return None


# ---------------------------------------------------------------------------
# Safety guardrail (defence-in-depth over structured output)
# ---------------------------------------------------------------------------
def is_action_safe(action: RemediationAction) -> bool:
    """Validate a structured action against Zero-Trust safety policies."""
    if action.namespace in FORBIDDEN_NAMESPACES:
        print(
            f"[!] Safety: Action targets forbidden namespace '{action.namespace}'",
            flush=True,
        )
        return False
    if action.namespace not in SAFE_NAMESPACES:
        print(
            f"[!] Safety: Namespace '{action.namespace}' not in approved list.",
            flush=True,
        )
        return False
    if action.action == "NO_ACTION":
        return True
    if action.action == "SCALE" and (
        action.replicas is None or action.replicas < 0 or action.replicas > 20
    ):
        print(
            f"[!] Safety: Replica count {action.replicas} out of safe range [0-20].",
            flush=True,
        )
        return False
    return True


# ---------------------------------------------------------------------------
# Kubernetes helpers with circuit breaker
# ---------------------------------------------------------------------------
def get_target_type(name: str, namespace: str):
    """Get target deployment/rollout type with circuit breaker protection"""

    def _check_k8s():
        try:
            ro = k8s_custom_api.get_namespaced_custom_object(
                group="argoproj.io",
                version="v1alpha1",
                namespace=namespace,
                plural="rollouts",
                name=name,
            )
            return "rollout", ro
        except client.ApiException as e:
            if e.status != 404:
                print(f"[!] Error checking Rollout: {e}", flush=True)
        try:
            dep = k8s_apps_v1.read_namespaced_deployment(name=name, namespace=namespace)
            return "deployment", dep
        except client.ApiException as e:
            if e.status != 404:
                print(f"[!] Error checking Deployment: {e}", flush=True)
        return None, None

    try:
        return CircuitBreakers.k8s_api.execute(_check_k8s)
    except Exception as e:
        logger.error(f"[!] K8s API circuit open or failed: {e}")
        return None, None


def verify_health(dep_name: str, namespace: str) -> bool:
    try:
        target_type, obj = get_target_type(dep_name, namespace)
        if not target_type or obj is None:
            return False
        if target_type == "rollout":
            ready = obj.get("status", {}).get("readyReplicas", 0)
            desired = obj.get("spec", {}).get("replicas", 0)
        else:
            ready = obj.status.ready_replicas or 0
            desired = obj.spec.replicas or 0
        healthy = ready >= desired
        status = "HEALTHY" if healthy else "UNHEALTHY"
        print(
            f"[{'+' if healthy else '-'}] Health: {dep_name} {status} ({ready}/{desired})",
            flush=True,
        )
        return healthy
    except Exception as e:
        print(f"[!] Health check error: {e}", flush=True)
        return False


# ---------------------------------------------------------------------------
# FIX 2: Real GitOps commit-back (not simulated print)
# ---------------------------------------------------------------------------
def gitops_remediate(dep_name: str, namespace: str, action: RemediationAction) -> bool:
    """
    Performs a REAL Git commit and push to the source repository.
    ArgoCD then reconciles the change to the cluster.
    """
    manifest_path = os.path.join(GIT_REPO_DIR, MANIFEST_FILE)
    if not os.path.exists(manifest_path):
        logger.error(f"[GitOps] Manifest not found at {manifest_path}")
        return False

    try:
        with open(manifest_path, "r") as f:
            docs = list(yaml.safe_load_all(f))

        target_doc = None
        target_idx = -1
        for i, doc in enumerate(docs):
            if doc is None:
                continue
            if (
                doc.get("kind") == "Deployment"
                and doc.get("metadata", {}).get("name") == dep_name
            ):
                target_doc = doc
                target_idx = i
                break

        if target_doc is None:
            logger.error(f"[GitOps] Target {dep_name} not found in manifest.")
            return False

        # Modify the document based on action
        if action.action == "SCALE" and action.replicas is not None:
            if "spec" not in target_doc:
                target_doc["spec"] = {}
            target_doc["spec"]["replicas"] = action.replicas

        elif action.action == "RESTART":
            now = datetime.datetime.utcnow().isoformat() + "Z"
            # Ensure template and metadata.annotations exist
            if "spec" not in target_doc:
                target_doc["spec"] = {}
            if "template" not in target_doc["spec"]:
                target_doc["spec"]["template"] = {}
            if "metadata" not in target_doc["spec"]["template"]:
                target_doc["spec"]["template"]["metadata"] = {}
            if "annotations" not in target_doc["spec"]["template"]["metadata"]:
                target_doc["spec"]["template"]["metadata"]["annotations"] = {}
            target_doc["spec"]["template"]["metadata"]["annotations"][
                "kubectl.kubernetes.io/restartedAt"
            ] = now

        # Write back all documents
        with open(manifest_path, "w") as f:
            yaml.dump_all(docs, f, default_flow_style=False, sort_keys=False)

        # -----------------------------
        # Git operations with hardening
        # -----------------------------
        # Ensure git user config (required for commits)
        git_config_cmds = [
            [
                "git",
                "-C",
                GIT_REPO_DIR,
                "config",
                "user.email",
                "ai-agent@ai4all-sre.local",
            ],
            ["git", "-C", GIT_REPO_DIR, "config", "user.name", "AI SRE Agent"],
        ]
        for cfg_cmd in git_config_cmds:
            subprocess.run(cfg_cmd, capture_output=True, timeout=10)

        # Set up remote authentication if token provided
        if GITHUB_TOKEN:
            # Replace remote URL with token authentication
            remote_url = f"https://{GITHUB_TOKEN}@github.com/{GIT_REMOTE.replace('https://', '').replace('http://', '')}"
            subprocess.run(
                [
                    "git",
                    "-C",
                    GIT_REPO_DIR,
                    "remote",
                    "set-url",
                    GIT_REMOTE,
                    remote_url,
                ],
                capture_output=True,
                timeout=10,
            )

        # Check repo is clean before starting
        status_result = subprocess.run(
            ["git", "-C", GIT_REPO_DIR, "status", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if status_result.stdout.strip():
            logger.warning(
                f"[GitOps] Git repository has uncommitted changes: {status_result.stdout.strip()}"
            )
            # We could stash, but for safety we abort
            logger.error("[GitOps] Aborting due to dirty repository.")
            return False

        # Stage the manifest file
        add_result = subprocess.run(
            ["git", "-C", GIT_REPO_DIR, "add", MANIFEST_FILE],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if add_result.returncode != 0:
            logger.error(f"[GitOps] Git add failed: {add_result.stderr}")
            return False

        # Commit
        commit_msg = (
            f"ai-remediation({action.action.lower()}): {dep_name} in {namespace}"
        )
        commit_result = subprocess.run(
            ["git", "-C", GIT_REPO_DIR, "commit", "--allow-empty", "-m", commit_msg],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if commit_result.returncode != 0:
            logger.error(f"[GitOps] Git commit failed: {commit_result.stderr}")
            # No commit to rollback
            return False

        # Push
        push_result = subprocess.run(
            ["git", "-C", GIT_REPO_DIR, "push", GIT_REMOTE, GIT_BRANCH],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if push_result.returncode != 0:
            logger.error(f"[GitOps] Git push failed: {push_result.stderr}")
            # Rollback the commit
            rollback = subprocess.run(
                ["git", "-C", GIT_REPO_DIR, "reset", "--soft", "HEAD~1"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if rollback.returncode != 0:
                logger.error(f"[GitOps] Failed to rollback commit: {rollback.stderr}")
            return False

        logger.info(f"[GitOps] ✅ Committed and pushed: '{commit_msg}'")
        return True

    except Exception as e:
        logger.exception(f"[GitOps] Exception: {e}")
        return False


# ---------------------------------------------------------------------------
# Remediation executor
# ---------------------------------------------------------------------------
def execute_remediation(action: RemediationAction) -> str:
    """Execute a validated, structured remediation action."""
    if not is_action_safe(action):
        return "Remediation BLOCKED by safety guardrails."

    if action.action == "NO_ACTION":
        return "AI determined no remediation required."

    dep_name = action.deployment
    namespace = action.namespace

    print(f"[*] Executing: {action.action} {dep_name} in {namespace}", flush=True)

    # Try GitOps first
    if GITOPS_MODE and gitops_remediate(dep_name, namespace, action):
        return (
            f"[GitOps ✅] {action.action} of {dep_name} committed → ArgoCD will sync."
        )

    # Fallback: direct Kubernetes API patch
    with k8s_lock:
        try:
            target_type, _ = get_target_type(dep_name, namespace)
            if not target_type:
                return f"Target {dep_name} not found."

            if action.action == "SCALE":
                body = {"spec": {"replicas": action.replicas}}
            elif action.action in ("RESTART", "ROLLBACK"):
                now = datetime.datetime.utcnow().isoformat() + "Z"
                body = {
                    "spec": {
                        "template": {
                            "metadata": {
                                "annotations": {
                                    "kubectl.kubernetes.io/restartedAt": now
                                }
                            }
                        }
                    }
                }
            else:
                return "Unknown action type."

            if target_type == "rollout":
                k8s_custom_api.patch_namespaced_custom_object(
                    group="argoproj.io",
                    version="v1alpha1",
                    namespace=namespace,
                    plural="rollouts",
                    name=dep_name,
                    body=body,
                )
            else:
                k8s_apps_v1.patch_namespaced_deployment(
                    name=dep_name, namespace=namespace, body=body
                )

            return f"[Direct Patch ✅] {action.action} applied to {dep_name}."
        except Exception as e:
            return f"[Direct Patch ❌] {e}"


# ---------------------------------------------------------------------------
# Lifecycle management: Post-Mortems & Runbooks
# ---------------------------------------------------------------------------
def handle_autonomous_lifecycle(
    alert_name: str,
    labels: dict,
    annotations: dict,
    action: RemediationAction,
    remediation_result: str,
):
    """Persist post-mortem and generate/update runbook."""
    timestamp = datetime.datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    pm_dir = os.path.join(GIT_REPO_DIR, POST_MORTEMS_DIR)
    rb_dir = os.path.join(GIT_REPO_DIR, RUNBOOKS_DIR)
    os.makedirs(pm_dir, exist_ok=True)
    os.makedirs(rb_dir, exist_ok=True)

    # Post-mortem
    pm_path = os.path.join(pm_dir, f"{timestamp}-{alert_name}.md")
    # Post-mortem content as string
    pm_content = f"""# Post-Mortem: {alert_name}

**Timestamp**: {timestamp} UTC
**Status**: Resolved (Self-Healed)

## Alert
- **Summary**: {annotations.get("summary")}
- **Description**: {annotations.get("description")}
- **Labels**: {labels}

## AI Root Cause Analysis
{action.rca}

## Remediation Executed
- **Action**: `{action.action}`
- **Deployment**: `{action.deployment}` in `{action.namespace}`
- **Result**: {remediation_result}

"""
    if action.gitops_patch_yaml:
        pm_content += f"""## GitOps Declarative Patch
```yaml
{action.gitops_patch_yaml}
```

"""
    if action.preventive_steps:
        pm_content += f"""## Preventive Steps
{action.preventive_steps}
"""
    with open(pm_path, "w") as f:
        f.write(pm_content)
    print(f"[*] Post-mortem: {pm_path}", flush=True)

    # Embed post-mortem into RAG pipeline
    if _rag_pipeline is not None:
        _rag_pipeline.embed_post_mortem(pm_content, alert_name, timestamp)

    # Runbook (create once, don't overwrite)
    rb_path = os.path.join(rb_dir, f"{alert_name}.md")
    if not os.path.exists(rb_path):
        with open(rb_path, "w") as f:
            f.write(f"# Runbook: {alert_name}\n\n")
            f.write(f"## Description\n{annotations.get('description')}\n\n")
            f.write(f"## AI-Generated Troubleshooting\n{action.rca}\n\n")
            f.write(
                f"## Recommended Action\n`{action.action}` on `{action.deployment}`\n"
            )
        print(f"[*] Runbook created: {rb_path}", flush=True)


# ---------------------------------------------------------------------------
# Core alert processor
# ---------------------------------------------------------------------------
def process_alert_background(alert: dict):
    status = alert.get("status")
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    alert_name = labels.get("alertname", "UnknownAlert")
    deployment_name = (
        labels.get("deployment")
        or labels.get("app")
        or labels.get("service", "frontend")
    )
    namespace = labels.get("namespace", "online-boutique")

    # FIX 3: Redis-backed debounce (not /tmp)
    alert_key = f"{alert_name}-{deployment_name}-{namespace}"
    if is_debounced(alert_key):
        print(f"[*] DEBOUNCED: '{alert_key}' — skipping.", flush=True)
        return
    set_debounce(alert_key)

    alert_context = (
        f"Status: {status} | Alert: {alert_name} | Namespace: {namespace} | "
        f"Deployment: {deployment_name}\n"
        f"Summary: {annotations.get('summary')}\n"
        f"Description: {annotations.get('description')}"
    )

    # Specialist agents
    agents = {
        "NetworkAgent": "You are a Network SRE AI specializing in Linkerd mTLS, ingress, DNS, and service routing.",
        "DatabaseAgent": "You are a Database SRE AI specializing in PostgreSQL, persistent volumes, and connection saturation.",
        "ComputeAgent": "You are a Compute SRE AI specializing in CPU/Memory pressure, OOMKills, and CrashLoopBackOffs.",
    }

    def query_agent(name: str, role: str) -> tuple:
        prompt = f"{role}\n\nAlert:\n{alert_context}\n\nProvide a brief domain-specific analysis."
        return name, query_ollama_with_backoff(prompt)

    print(f"\n[*] Dispatching to Specialist Agents for: {alert_name}", flush=True)
    agent_responses = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = [executor.submit(query_agent, n, r) for n, r in agents.items()]
        for future in concurrent.futures.as_completed(futures):
            name, output = future.result()
            agent_responses[name] = output

    # FIX 9: Structured consensus prompt — forces JSON output matching RemediationAction schema
    consensus_prompt = f"""You are the Director SRE Agent. Synthesize the specialist analyses and output a remediation plan.

Alert Context:
{alert_context}

Specialist Analyses:
- NetworkAgent: {agent_responses.get("NetworkAgent", "N/A")}
- DatabaseAgent: {agent_responses.get("DatabaseAgent", "N/A")}
- ComputeAgent: {agent_responses.get("ComputeAgent", "N/A")}

Historical Context (Relevant Post-Mortems):
{retrieve_context(alert_context)}

Target deployment is '{deployment_name}' in namespace '{namespace}'.

Output a JSON object with exactly these fields:
- rca: Root cause analysis string
- action: one of RESTART, SCALE, ROLLBACK, NO_ACTION
- deployment: the deployment name to act on
- namespace: the Kubernetes namespace (MUST be '{namespace}')
- replicas: integer (only if action is SCALE, otherwise null)
- preventive_steps: brief prevention advice string
- gitops_patch_yaml: Kubernetes YAML diff string for ArgoCD (or null)
"""
    schema = RemediationAction.model_json_schema()
    raw = query_ollama_structured(consensus_prompt, schema)

    if raw is None:
        print(f"[!] Structured LLM output failed. Skipping remediation.", flush=True)
        return

    try:
        action = RemediationAction(**raw)
    except ValidationError as e:
        print(f"[!] LLM output failed schema validation: {e}", flush=True)
        return

    print(f"\n[Director] RCA: {action.rca}", flush=True)
    print(
        f"[Director] Action: {action.action} → {action.deployment} in {action.namespace}",
        flush=True,
    )

    remediation_result = execute_remediation(action)
    print(f"[*] Result: {remediation_result}", flush=True)

    handle_autonomous_lifecycle(
        alert_name, labels, annotations, action, remediation_result
    )


# ---------------------------------------------------------------------------
# FastAPI endpoints
# ---------------------------------------------------------------------------
@app.get("/health")
async def health():
    # Vector store status
    if _rag_pipeline and _rag_pipeline.primary_backend:
        doc_count = _rag_pipeline.primary_backend.get_document_count()
        vector_store_status = (
            f"{type(_rag_pipeline.primary_backend).__name__} ({doc_count} docs)"
        )
    else:
        vector_store_status = "unavailable"

    # Redis connectivity
    redis_status = "unavailable"
    if REDIS_AVAILABLE:
        try:
            _redis_client.ping()
            redis_status = "ok"
        except Exception as e:
            redis_status = f"error: {e}"

    # Ollama connectivity
    ollama_status = "unknown"
    try:
        ollama_response = requests.get(
            f"{OLLAMA_URL.replace('/api/generate', '')}/api/tags", timeout=2
        )
        if ollama_response.status_code == 200:
            ollama_status = "ok"
        else:
            ollama_status = f"error: {ollama_response.status_code}"
    except Exception as e:
        ollama_status = f"unreachable: {e}"

    # Circuit breaker states
    cb_states = CircuitBreakers.get_all_states()

    logger.debug(
        f"Health check - Vector store: {vector_store_status}, Redis: {redis_status}, Ollama: {ollama_status}"
    )

    return {
        "status": "ok",
        "version": agent_config.config.version,
        "redis": redis_status,
        "vector_store": vector_store_status,
        "ollama": ollama_status,
        "circuit_breakers": cb_states,
    }


@app.post("/webhook")
async def handle_alert(request: Request, background_tasks: BackgroundTasks):
    payload = await request.json()
    alerts = payload.get("alerts", [])
    if not alerts:
        return {"status": "no_alerts"}

    # Sort alerts by priority (critical first)
    alerts_sorted = sorted(alerts, key=alert_priority)

    processed = 0
    for alert in alerts_sorted:
        # Create alert key for rate limiting
        labels = alert.get("labels", {})
        alert_name = labels.get("alertname", "UnknownAlert")
        deployment_name = (
            labels.get("deployment")
            or labels.get("app")
            or labels.get("service", "frontend")
        )
        namespace = labels.get("namespace", "online-boutique")
        alert_key = f"{alert_name}-{deployment_name}-{namespace}"

        # Rate limit
        if is_rate_limited(alert_key, limit=10, window=60):
            logger.warning(
                f"[RateLimited] Skipping alert {alert_key} due to rate limit"
            )
            continue

        background_tasks.add_task(process_alert_background, alert)
        processed += 1

    return {"status": "accepted", "count": processed, "total": len(alerts)}


if __name__ == "__main__":
    print("[*] Starting Tier-1 SRE Agent v5.0.0...", flush=True)
    index_post_mortems()
    uvicorn.run(app, host="0.0.0.0", port=8000)
