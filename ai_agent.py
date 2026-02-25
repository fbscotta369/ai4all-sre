import os
import requests
import uvicorn
import datetime
from fastapi import FastAPI, Request
from kubernetes import client, config

app = FastAPI()

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama.default.svc.cluster.local:11434/api/generate")
RUNBOOKS_DIR = "runbooks"
POST_MORTEMS_DIR = "post-mortems"
SAFE_NAMESPACES = ["online-boutique"]
FORBIDDEN_KEYWORDS = ["DELETE", "NAMESPACE", "KUBE-SYSTEM", "KYVERNO", "LINKERD"]

# Initialize Kubernetes client
try:
    config.load_incluster_config()
except:
    try:
        config.load_kube_config()
    except:
        print("[!] Warning: Could not load Kubernetes config.")

k8s_apps_v1 = client.AppsV1Api()

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

def execute_remediation(action_text):
    """
    Experimental: Parse AI recommendation and execute it with Safety Guardrails.
    Example: 'RESTART DEPLOYMENT cartservice IN online-boutique'
    """
    if not is_action_safe(action_text):
        return "Remediation BLOCKED by Safety Guardrails."

    print(f"[*] AI Safety Check passed. Executing: {action_text}")
    try:
        # Simple extraction logic for demonstration
        if "RESTART DEPLOYMENT" in action_text.upper():
            parts = action_text.split()
            dep_name = None
            namespace = "default"
            
            for i, part in enumerate(parts):
                if part.upper() == "DEPLOYMENT" and i + 1 < len(parts):
                    dep_name = parts[i+1]
                if part.upper() == "IN" and i + 1 < len(parts):
                    namespace = parts[i+1]
            
            if dep_name:
                print(f"[*] Triggering rollout restart for {dep_name} in {namespace}...")
                now = datetime.datetime.now().isoformat()
                body = {
                    'spec': {
                        'template': {
                            'metadata': {
                                'annotations': {
                                    'kubectl.kubernetes.io/restartedAt': now
                                }
                            }
                        }
                    }
                }
                k8s_apps_v1.patch_namespaced_deployment(name=dep_name, namespace=namespace, body=body)
                return f"Successfully restarted deployment {dep_name} in {namespace}"
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
        f.write(f"{ai_response}\n")
    
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
    else:
        print(f"[*] Existing runbook found at {runbook_path}")

@app.post("/webhook")
async def handle_alert(request: Request):
    payload = await request.json()
    alerts = payload.get("alerts", [])
    if not alerts:
        return {"status": "no alerts"}

    for alert in alerts:
        status = alert.get("status")
        labels = alert.get("labels", {})
        annotations = alert.get("annotations", {})
        alert_name = labels.get('alertname', 'UnknownAlert')
        
        is_predictive = labels.get('severity') == 'warning' or "PREDICTIVE" in alert_name.upper()

        prompt = f"""
        You are an elite Hyper-Autonomous SRE AI.
        A {'PREDICTIVE ' if is_predictive else ''}alert has been triggered.
        
        Status: {status} | Alert Name: {alert_name} | Namespace: {labels.get('namespace')}
        
        Summary: {annotations.get('summary')}
        Description: {annotations.get('description')}
        
        Provide:
        1. **RCA**: Precision theory on failure.
        2. **Remediation**: Command: RESTART DEPLOYMENT <name> IN <namespace>
        3. **Predictive Insight**: Prevention steps.
        
        Concise, elite, and actionable.
        """
        
        try:
            print(f"\n[*] Sending alert {alert_name} to Llama 3 for Hyper-Autonomous Analysis...")
            response = requests.post(OLLAMA_URL, json={
                "model": "llama3",
                "prompt": prompt,
                "stream": False
            })
            
            if response.status_code == 200:
                ai_analysis = response.json().get("response", "")
                print(f"\n[AI Full Lifecycle Analysis for {alert_name}]:\n{ai_analysis}\n")
                
                # Full Lifecycle Management
                handle_autonomous_lifecycle(alert_name, labels, annotations, ai_analysis)

                if "RESTART DEPLOYMENT" in ai_analysis.upper():
                    for line in ai_analysis.split('\n'):
                        if "RESTART DEPLOYMENT" in line.upper():
                            result = execute_remediation(line)
                            print(f"[*] Remediation Result: {result}")
                
            else:
                print(f"[!] Failed to reach Ollama: {response.text}")
                
        except Exception as e:
            print(f"[!] Error querying Ollama: {e}")

    return {"status": "processed", "lifecycle": "documented"}

if __name__ == "__main__":
    print("[*] Starting Hyper-Autonomous SRE Agent...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
