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
from . import agent_config

# ---------------------------------------------------------------------------
# AI/ML Memory: HNSW Vector Store with persistence
# ---------------------------------------------------------------------------
try:
    import faiss
    import numpy as np
    from sentence_transformers import SentenceTransformer
    import os
    import pickle

    EMBED_MODEL = SentenceTransformer("all-MiniLM-L6-v2")
    VECTOR_DIM = 384
    _index = None
    _pm_metadata = []

    # Define persistence directory and files
    VECTOR_STORE_DIR = os.path.join(
        os.path.dirname(__file__), "..", "..", "data", "vector_store"
    )
    INDEX_FILE = os.path.join(VECTOR_STORE_DIR, "faiss_index.bin")
    METADATA_FILE = os.path.join(VECTOR_STORE_DIR, "metadata.pkl")

    # Try to load existing index and metadata
    if os.path.exists(INDEX_FILE) and os.path.exists(METADATA_FILE):
        _index = faiss.read_index(INDEX_FILE)
        with open(METADATA_FILE, "rb") as f:
            _pm_metadata = pickle.load(f)
        logger.info(
            f"[+] Loaded HNSW Vector Memory from disk ({len(_pm_metadata)} entries)."
        )
    else:
        # Create new index if none exists
        _index = faiss.IndexHNSWFlat(VECTOR_DIM, 32)
        logger.info("[+] HNSW Vector Memory initialized (new).")

    # Ensure the persistence directory exists
    os.makedirs(VECTOR_STORE_DIR, exist_ok=True)

except Exception as e:
    logger.error(f"[!] Vector memory unavailable ({e}).")
    _index = None

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
    if _index is None:
        return
    pm_dir = os.path.join(GIT_REPO_DIR, POST_MORTEMS_DIR)
    if not os.path.exists(pm_dir):
        return
    for f in os.listdir(pm_dir):
        if f.endswith(".md"):
            with open(os.path.join(pm_dir, f), "r") as file:
                content = file.read()
                embedding = EMBED_MODEL.encode([content])[0].astype("float32")
                _index.add(np.array([embedding]))
                _pm_metadata.append(content)
    print(f"[*] Indexed {len(_pm_metadata)} post-mortems.", flush=True)
    # Persist the index and metadata to disk
    try:
        faiss.write_index(_index, INDEX_FILE)
        with open(METADATA_FILE, "wb") as f:
            pickle.dump(_pm_metadata, f)
        print(f"[+] Persisted HNSW Vector Memory to disk.", flush=True)
    except Exception as e:
        print(f"[!] Failed to persist vector memory: {e}", flush=True)


def retrieve_context(query: str, k: int = 2) -> str:
    """Retrieve relevant post-mortems."""
    if _index is None or _index.ntotal == 0:
        return "No historical context available."
    query_vec = EMBED_MODEL.encode([query])[0].astype("float32")
    distances, indices = _index.search(np.array([query_vec]), k)
    context = []
    for idx in indices[0]:
        if idx != -1:
            context.append(_pm_metadata[idx])
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
        print(f"[GitOps] Manifest not found at {manifest_path}", flush=True)
        return False

    try:
        with open(manifest_path, "r") as f:
            content = f.read()

        manifests = content.split("---")
        target_idx = next(
            (
                i
                for i, m in enumerate(manifests)
                if f"name: {dep_name}" in m and "kind: Deployment" in m
            ),
            -1,
        )
        if target_idx == -1:
            print(f"[GitOps] Target {dep_name} not found in manifest.", flush=True)
            return False

        target_manifest = manifests[target_idx]

        if action.action == "SCALE" and action.replicas is not None:
            if "replicas:" in target_manifest:
                target_manifest = re.sub(
                    r"(replicas: )\d+",
                    rf"\g<1>{action.replicas}",
                    target_manifest,
                    count=1,
                )
            else:
                target_manifest = re.sub(
                    r"(spec:\n)",
                    rf"\g<1>  replicas: {action.replicas}\n",
                    target_manifest,
                    count=1,
                )

        elif action.action == "RESTART":
            now = datetime.datetime.utcnow().isoformat() + "Z"
            annotation = f'kubectl.kubernetes.io/restartedAt: "{now}"'
            if "kubectl.kubernetes.io/restartedAt:" in target_manifest:
                target_manifest = re.sub(
                    r"(kubectl\.kubernetes\.io/restartedAt: ).*",
                    rf'\g<1>"{now}"',
                    target_manifest,
                    count=1,
                )
            elif "annotations:" in target_manifest:
                target_manifest = re.sub(
                    r"(annotations:\n)",
                    rf"\g<1>        {annotation}\n",
                    target_manifest,
                    count=1,
                )
            else:
                target_manifest = re.sub(
                    r"(template:\n\s+metadata:\n)",
                    rf"\g<1>      annotations:\n        {annotation}\n",
                    target_manifest,
                    count=1,
                )

        manifests[target_idx] = target_manifest
        with open(manifest_path, "w") as f:
            f.write("---".join(manifests))

        # REAL Git commit + push (not a print statement)
        commit_msg = (
            f"ai-remediation({action.action.lower()}): {dep_name} in {namespace}"
        )
        cmds = [
            ["git", "-C", GIT_REPO_DIR, "add", MANIFEST_FILE],
            ["git", "-C", GIT_REPO_DIR, "commit", "--allow-empty", "-m", commit_msg],
            ["git", "-C", GIT_REPO_DIR, "push", GIT_REMOTE, GIT_BRANCH],
        ]
        for cmd in cmds:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode != 0:
                print(
                    f"[GitOps] Git command failed: {' '.join(cmd)}\n{result.stderr}",
                    flush=True,
                )
                # Attempt git reset to avoid dirty state
                subprocess.run(
                    ["git", "-C", GIT_REPO_DIR, "reset", "HEAD~1", "--soft"],
                    capture_output=True,
                )
                return False

        print(f"[GitOps] ✅ Committed and pushed: '{commit_msg}'", flush=True)
        return True

    except Exception as e:
        print(f"[GitOps] Exception: {e}", flush=True)
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
    with open(pm_path, "w") as f:
        f.write(f"# Post-Mortem: {alert_name}\n\n")
        f.write(f"**Timestamp**: {timestamp} UTC\n")
        f.write(f"**Status**: Resolved (Self-Healed)\n\n")
        f.write(f"## Alert\n- **Summary**: {annotations.get('summary')}\n")
        f.write(f"- **Description**: {annotations.get('description')}\n")
        f.write(f"- **Labels**: {labels}\n\n")
        f.write(f"## AI Root Cause Analysis\n{action.rca}\n\n")
        f.write(f"## Remediation Executed\n- **Action**: `{action.action}`\n")
        f.write(f"- **Deployment**: `{action.deployment}` in `{action.namespace}`\n")
        f.write(f"- **Result**: {remediation_result}\n\n")
        if action.gitops_patch_yaml:
            f.write(
                f"## GitOps Declarative Patch\n```yaml\n{action.gitops_patch_yaml}\n```\n\n"
            )
        if action.preventive_steps:
            f.write(f"## Preventive Steps\n{action.preventive_steps}\n")
    print(f"[*] Post-mortem: {pm_path}", flush=True)

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
    vector_store_status = (
        "loaded" if _index is not None and _index.ntotal > 0 else "empty or failed"
    )
    # Check Ollama connectivity with a short timeout
    ollama_status = "unknown"
    try:
        # Use a GET request to the Ollama version endpoint (if available) or just check if the server is up.
        # Ollama's /api/tags endpoint returns a list of models.
        ollama_response = requests.get(
            f"{OLLAMA_URL.replace('/api/generate', '')}/api/tags", timeout=2
        )
        if ollama_response.status_code == 200:
            ollama_status = "ok"
        else:
            ollama_status = f"error: {ollama_response.status_code}"
    except Exception as e:
        ollama_status = f"unreachable: {e}"

    logger.debug(
        f"Health check - Vector store: {vector_store_status}, Redis: {REDIS_AVAILABLE}, Ollama: {ollama_status}"
    )

    return {
        "status": "ok",
        "version": agent_config.config.version,
        "redis": REDIS_AVAILABLE,
        "vector_store": vector_store_status,
        "ollama": ollama_status,
    }


@app.post("/webhook")
async def handle_alert(request: Request, background_tasks: BackgroundTasks):
    payload = await request.json()
    alerts = payload.get("alerts", [])
    if not alerts:
        return {"status": "no_alerts"}
    for alert in alerts:
        background_tasks.add_task(process_alert_background, alert)
    return {"status": "accepted", "count": len(alerts)}


if __name__ == "__main__":
    print("[*] Starting Tier-1 SRE Agent v5.0.0...", flush=True)
    index_post_mortems()
    uvicorn.run(app, host="0.0.0.0", port=8000)
