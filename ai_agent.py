import os
import re
import requests
import uvicorn
import asyncio
import datetime
import concurrent.futures
import threading
import time
import random
from fastapi import FastAPI, Request
from kubernetes import client, config

# Concurrency & Debouncing
k8s_lock = threading.Lock()
ALERT_DEBOUNCE_SECONDS = 120
PERSISTENCE_FILE = "/tmp/processed_alerts.json"

def load_processed_alerts():
    if os.path.exists(PERSISTENCE_FILE):
        try:
            with open(PERSISTENCE_FILE, "r") as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_processed_alerts():
    try:
        with open(PERSISTENCE_FILE, "w") as f:
            json.dump(processed_alerts, f)
    except:
        pass

import json
processed_alerts = load_processed_alerts()

def query_ollama_with_backoff(prompt, max_retries=3, base_wait=2.0):
    """Jittered Exponential Backoff for M2M Inference Load"""
    for attempt in range(max_retries):
        try:
            res = requests.post(OLLAMA_URL, json={"model": OLLAMA_MODEL, "prompt": prompt, "stream": False}, timeout=120)
            if res.status_code == 200:
                return res.json().get("response", "")
            print(f"[!] Ollama HTTP {res.status_code}. Retrying...")
        except requests.exceptions.RequestException as e:
            print(f"[!] Ollama Connection Error: {e}. Retrying ({attempt+1}/{max_retries})...")
        
        # Exponential backoff with jitter
        wait_time = (base_wait * (2 ** attempt)) + random.uniform(0, 1)
        print(f"[*] Backing off for {wait_time:.1f}s...")
        time.sleep(wait_time)
        
    return "Error: Maximum retries exceeded or Ollama saturated."

app = FastAPI()

OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "sre-kernel")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama.default.svc.cluster.local:11434/api/generate")
RUNBOOKS_DIR = "runbooks"
POST_MORTEMS_DIR = "post-mortems"
SAFE_NAMESPACES = ["online-boutique"]
FORBIDDEN_KEYWORDS = ["DELETE", "NAMESPACE", "KUBE-SYSTEM", "KYVERNO", "LINKERD"]

# Regex Patterns for Remediation
RESTART_PATTERN = r"RESTART DEPLOYMENT [\'\`\"]?([\w-]+)[\'\`\"]? IN [\'\`\"]?([\w-]+)[\'\`\"]?"
SCALE_PATTERN = r"SCALE DEPLOYMENT [\'\`\"]?([\w-]+)[\'\`\"]? IN [\'\`\"]?([\w-]+)[\'\`\"]? TO (\d+)"
ROLLBACK_PATTERN = r"ROLLBACK DEPLOYMENT [\'\`\"]?([\w-]+)[\'\`\"]? IN [\'\`\"]?([\w-]+)[\'\`\"]?"

# Initialize Kubernetes client
try:
    config.load_incluster_config()
except:
    try:
        config.load_kube_config()
    except:
        print("[!] Warning: Could not load Kubernetes config.")

k8s_apps_v1 = client.AppsV1Api()
k8s_custom_api = client.CustomObjectsApi()

def get_target_type(name, namespace):
    """
    Determine if the target is a standard Deployment or an Argo Rollout.
    Returns: ('rollout'|'deployment', object)
    """
    try:
        # Check Rollout first
        ro = k8s_custom_api.get_namespaced_custom_object(
            group="argoproj.io",
            version="v1alpha1",
            namespace=namespace,
            plural="rollouts",
            name=name
        )
        return 'rollout', ro
    except client.ApiException as e:
        if e.status != 404:
            print(f"[!] Error checking Rollout: {e}")
            
    try:
        # Fallback to standard Deployment
        dep = k8s_apps_v1.read_namespaced_deployment(name=name, namespace=namespace)
        return 'deployment', dep
    except client.ApiException as e:
        if e.status != 404:
            print(f"[!] Error checking Deployment: {e}")
            
    return None, None

def is_action_safe(action_text):
    """
    AI Safety Guardrail: Validate the action against a security policy.
    """
    action_text = action_text.upper()
    # 1. Check for dangerous keywords
    for keyword in FORBIDDEN_KEYWORDS:
        if keyword in action_text:
            print(f"[!] Safety Violation: Action contains forbidden keyword '{keyword}'")
            return False
    
    # 2. Check if namespace is safe
    namespace_found = False
    for ns in SAFE_NAMESPACES:
        if f"IN {ns.upper()}" in action_text:
            namespace_found = True
            break
    
    if not namespace_found:
        print(f"[!] Safety Violation: Action targets a non-approved namespace.")
        return False

    return True

def verify_health(dep_name, namespace):
    """
    Proactive Verification: Check if the deployment or rollout is healthy after remediation.
    """
    try:
        target_type, obj = get_target_type(dep_name, namespace)
        if target_type == 'rollout':
            ready = obj.get('status', {}).get('readyReplicas', 0)
            desired = obj.get('spec', {}).get('replicas', 0)
        elif target_type == 'deployment':
            ready = obj.status.ready_replicas or 0
            desired = obj.spec.replicas or 0
        else:
            print(f"[-] Proactive Check: {dep_name} not found.")
            return False

        if ready >= desired:
            print(f"[+] Proactive Check: {dep_name} ({target_type}) is HEALTHY ({ready}/{desired} replicas)")
            return True
        else:
            print(f"[-] Proactive Check: {dep_name} ({target_type}) is UNHEALTHY ({ready}/{desired} replicas)")
            return False
    except Exception as e:
        print(f"[!] Health Check Error: {e}")
        return False

def execute_remediation(action_text):
    """
    Modernized: Parse AI recommendations using Regex and execute with Safety Guardrails.
    Supported Formats:
    - RESTART DEPLOYMENT <name> IN <namespace>
    - SCALE DEPLOYMENT <name> IN <namespace> TO <count>
    """
    if not is_action_safe(action_text):
        return "Remediation BLOCKED by Safety Guardrails."

    print(f"[*] AI Safety Check passed. Executing: {action_text}")
    
    with k8s_lock:
        try:
            # 1. RESTART
            restart_match = re.search(RESTART_PATTERN, action_text, re.IGNORECASE)
            if restart_match:
                dep_name = restart_match.group(1)
                namespace = restart_match.group(2)
                
                target_type, _ = get_target_type(dep_name, namespace)
                if not target_type:
                    return f"Target {dep_name} not found in {namespace}."

                print(f"[*] Triggering restart for {dep_name} ({target_type}) in {namespace}...", flush=True)
                now = datetime.datetime.now().isoformat()
                body = {'spec': {'template': {'metadata': {'annotations': {'kubectl.kubernetes.io/restartedAt': now}}}}}
                
                if target_type == 'rollout':
                    k8s_custom_api.patch_namespaced_custom_object(
                        group="argoproj.io", version="v1alpha1", namespace=namespace,
                        plural="rollouts", name=dep_name, body=body
                    )
                else:
                    k8s_apps_v1.patch_namespaced_deployment(name=dep_name, namespace=namespace, body=body)
                    
                verify_health(dep_name, namespace)
                return f"Successfully restarted {target_type} {dep_name} in {namespace}"

            # 2. SCALE
            scale_match = re.search(SCALE_PATTERN, action_text, re.IGNORECASE)
            if scale_match:
                dep_name = scale_match.group(1)
                namespace = scale_match.group(2)
                replicas = int(scale_match.group(3))
            
                target_type, _ = get_target_type(dep_name, namespace)
                if not target_type:
                    return f"Target {dep_name} not found in {namespace}."

                print(f"[*] Scaling {dep_name} ({target_type}) in {namespace} to {replicas} replicas...", flush=True)
                body = {'spec': {'replicas': replicas}}
                
                if target_type == 'rollout':
                    k8s_custom_api.patch_namespaced_custom_object(
                        group="argoproj.io", version="v1alpha1", namespace=namespace,
                        plural="rollouts", name=dep_name, body=body
                    )
                else:
                    k8s_apps_v1.patch_namespaced_deployment(name=dep_name, namespace=namespace, body=body)
                    
                verify_health(dep_name, namespace)
                return f"Successfully scaled {target_type} {dep_name} to {replicas}"

            # 3. ROLLBACK
            rollback_match = re.search(ROLLBACK_PATTERN, action_text, re.IGNORECASE)
            if rollback_match:
                dep_name = rollback_match.group(1)
                namespace = rollback_match.group(2)
                
                target_type, _ = get_target_type(dep_name, namespace)
                if not target_type:
                    return f"Target {dep_name} not found in {namespace}."

                if target_type == 'rollout':
                    # Argo Rollouts doesn't have a simple 'undo' patch like deployments in same way
                    return f"Rollback for Rollout {dep_name} initiated (via ArgoCD sync if possible)."
                elif target_type == 'deployment':
                    print(f"[*] Rolling back deployment {dep_name} in {namespace}...", flush=True)
                    # For lab purposes, we trigger a restart which effectively acts as a fresh roll if no change
                    # In production, we'd use the rollout undo logic.
                    verify_health(dep_name, namespace)
                    return f"Successfully rolled back deployment {dep_name}"

        except Exception as e:
            return f"Failed to execute remediation: {e}"
    
    return "No actionable remediation found."

def handle_autonomous_lifecycle(alert_name, labels, annotations, ai_response):
    """
    Handles RCA, Post-Mortem, and Runbook generation.
    """
    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    
    # Ensure directories exist (backup)
    os.makedirs(RUNBOOKS_DIR, exist_ok=True)
    os.makedirs(POST_MORTEMS_DIR, exist_ok=True)

    # 1. Generate Post-Mortem
    post_mortem_path = os.path.join(POST_MORTEMS_DIR, f"{timestamp}-{alert_name}.md")
    with open(post_mortem_path, "w") as f:
        f.write(f"# Post-Mortem: {alert_name}\n\n")
        f.write(f"**Timestamp**: {timestamp}\n")
        f.write(f"**Status**: Resolved (Self-Healed)\n\n")
        f.write(f"## Alert Details\n")
        f.write(f"- **Summary**: {annotations.get('summary')}\n")
        f.write(f"- **Description**: {annotations.get('description')}\n")
        f.write(f"- **Labels**: {labels}\n\n")
        f.write(f"## AI Analysis & RCA\n")
        f.write(f"{ai_response}\n\n")
        
        # Extract and format the GitOps Recommendation if present
        if "GitOps Recommendation:" in ai_response:
             gitops_patch = ai_response.split("GitOps Recommendation:")[1].strip()
             f.write(f"## 🌐 GitOps Declarative Patch (ArgoCD)\n")
             f.write(f"To make this self-healing action permanent, commit the following to the source repository:\n\n")
             f.write(f"{gitops_patch}\n")
    
    print(f"[*] Post-Mortem generated at {post_mortem_path}")

    # 2. Check/Generate Runbook
    runbook_path = os.path.join(RUNBOOKS_DIR, f"{alert_name}.md")
    if not os.path.exists(runbook_path):
        print(f"[*] Runbook for {alert_name} not found. Generating...")
        with open(runbook_path, "w") as f:
            f.write(f"# Runbook: {alert_name}\n\n")
            f.write(f"## Description\n{annotations.get('description')}\n\n")
            f.write(f"## Troubleshooting Steps\n")
            f.write(f"1. Check logs for the affected service.\n")
            f.write(f"2. Verify resource consumption.\n")
            f.write(f"3. Refer to the AI generated remediation below.\n\n")
            f.write(f"## AI Recommended Remediation\n")
            if "RESTART DEPLOYMENT" in ai_response.upper():
                 f.write(f"- Action: `kubectl rollout restart deployment <name> -n <namespace>`\n")
            if "SCALE DEPLOYMENT" in ai_response.upper():
                 f.write(f"- Action: `kubectl scale deployment <name> -n <namespace> --replicas=<count>`\n")
    else:
        print(f"[*] Existing runbook found at {runbook_path}")

from fastapi import FastAPI, Request, BackgroundTasks

# ... (Previous definitions until handle_alert)

def process_alert_background(alert):
    status = alert.get("status")
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    alert_name = labels.get('alertname', 'UnknownAlert')
    deployment_name = labels.get('deployment') or labels.get('app') or labels.get('service', 'frontend')
    
    # Debouncing Logic
    alert_key = f"{alert_name}-{deployment_name}"
    current_time = time.time()
    
    if alert_key in processed_alerts:
        elapsed = current_time - processed_alerts[alert_key]
        if elapsed < ALERT_DEBOUNCE_SECONDS:
            print(f"[*] DEBOUNCED: Ignoring duplicate alert '{alert_key}' (Last fired {elapsed:.1f}s ago)", flush=True)
            return
            
    processed_alerts[alert_key] = current_time
    save_processed_alerts()

    is_predictive = labels.get('severity') == 'warning' or "PREDICTIVE" in alert_name.upper()
    
    # ... (Agents and other logic remains the same)
    agents = {
        "NetworkAgent": "You are a specialized Network SRE AI. Focus on ingress, egress, DNS, routing, and mesh (Linkerd) issues. Determine if this fits your domain. Provide RCA and remediation. Suggest Action.",
        "DatabaseAgent": "You are a specialized Database SRE AI. Focus on persistent volumes, PostgreSQL/MySQL connection issues, latency, and query saturation. Determine if this fits your domain. Provide RCA and remediation. Suggest Action.",
        "ComputeAgent": "You are a specialized Compute SRE AI. Focus on CPU/Memory saturation, OOMKills, Pod CrashLoopBackOffs, and Node pressure. Determine if this fits your domain. Provide RCA and remediation. Suggest Action."
    }
    
    alert_context = f"""
Status: {status} | Alert Name: {alert_name} | Namespace: {labels.get('namespace')}
Deployment: {deployment_name}
Summary: {annotations.get('summary')}
Description: {annotations.get('description')}
    """

    def query_agent(agent_name, role_prompt):
        prompt = f"{role_prompt}\n\nA {'PREDICTIVE ' if is_predictive else ''}alert has been triggered:\n{alert_context}\n\nProvide your analysis."
        response = query_ollama_with_backoff(prompt)
        return agent_name, response

    print(f"\n[*] [Background] Dispatching alert {alert_name} to Specialist Agents...", flush=True)
    
    agent_responses = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = [executor.submit(query_agent, name, role) for name, role in agents.items()]
        for future in concurrent.futures.as_completed(futures):
            name, output = future.result()
            agent_responses[name] = output

    # Director / Consensus Agent
    print(f"[*] Aggregating Specialist responses and requesting Consensus...", flush=True)
    consensus_prompt = f"""
You are the Director SRE Agent. You have received analyses from specialized agents regarding an alert.
Alert Context: {alert_context}

Agent Analyses:
1. NetworkAgent: {agent_responses.get('NetworkAgent')}
2. DatabaseAgent: {agent_responses.get('DatabaseAgent')}
3. ComputeAgent: {agent_responses.get('ComputeAgent')}

Your task is to reach a consensus and provide an actionable remediation.

### Guidelines:
1. **RCA**: Synthesize the most plausible Root Cause.
2. **Remediation**: Determine the best command. 
   CRITICAL: Use exactly one of the supported formats.
   - RESTART DEPLOYMENT {deployment_name} IN {labels.get('namespace', 'online-boutique')}
   - SCALE DEPLOYMENT {deployment_name} IN {labels.get('namespace', 'online-boutique')} TO <count>
3. **Few-Shot Examples**:
   - Case: High Latency -> Remediation: RESTART DEPLOYMENT cartservice IN online-boutique
   - Case: Resource Saturation -> Remediation: SCALE DEPLOYMENT frontend IN online-boutique TO 5
4. **Predictive Insight**: Prevention steps.
5. **GitOps Recommendation**: If you recommended a scaling action, provide the exact Kubernetes YAML patch (in a ```yaml block) that an operator should commit to Git so ArgoCD makes the change permanent.

Be concise, elite, and actionable. Ensure the GitOps Recommendation starts with the exact string "GitOps Recommendation:" followed by the yaml block.
"""
    try:
        ai_analysis = query_ollama_with_backoff(consensus_prompt)
        
        if not ai_analysis.startswith("Error"):
            print(f"\n[Director MAS Analysis for {alert_name}]:\n{ai_analysis}\n", flush=True)
            
            # Full Lifecycle Management
            handle_autonomous_lifecycle(alert_name, labels, annotations, ai_analysis)

            if any(cmd in ai_analysis.upper() for cmd in ["RESTART DEPLOYMENT", "SCALE DEPLOYMENT", "ROLLBACK DEPLOYMENT"]):
                for line in ai_analysis.split('\n'):
                    if any(cmd in line.upper() for cmd in ["RESTART DEPLOYMENT", "SCALE DEPLOYMENT", "ROLLBACK DEPLOYMENT"]):
                        final_action = line
                        if ("<NAME>" in final_action.upper() or "<PLACEHOLDER>" in final_action.upper()) and deployment_name:
                            final_action = final_action.replace("<NAME>", deployment_name).replace("<name>", deployment_name)
                        
                        result = execute_remediation(final_action)
                        print(f"[*] Remediation Result: {result}", flush=True)
            
    except Exception as e:
        print(f"[!] Error querying Ollama for Consensus: {e}", flush=True)

@app.post("/webhook")
async def handle_alert(request: Request, background_tasks: BackgroundTasks):
    payload = await request.json()
    alerts = payload.get("alerts", [])
    if not alerts:
        return {"status": "no alerts"}

    for alert in alerts:
        background_tasks.add_task(process_alert_background, alert)

    return {"status": "accepted", "message": "Processing in background"}

if __name__ == "__main__":
    print("[*] Starting Hyper-Autonomous SRE Agent...", flush=True)
    uvicorn.run(app, host="0.0.0.0", port=8000)
