#!/usr/bin/env python3
import os
import json
import re

# Paths
POST_MORTEMS_DIR = "post-mortems"
OUTPUT_FILE = "ai-lab/fine-tuning/dataset_generated.jsonl"

# expert SRE/DevSecOps Knowledge Bootstrap Library
BOOTSTRAP_LIBRARY = [
    {"input": "High latency detected on frontend. Linkerd p99 shows 1.2s spike. CPU at 90%. No memory issues.", "output": "Root Cause: Ingress-Nginx buffering saturated due to unoptimized sysctl 'fs.inotify.max_user_instances'. Action: Increase inotify limits and restart frontend pods to clear buffer cache."},
    {"input": "ArgoCD shows synchronization failed for 'online-boutique'. Error: secret 'linkerd-trust-anchor' not found.", "output": "Root Cause: GitOps Drift. The trust anchor was manually rotated but the Terraform state was not updated. Action: Run 'terraform apply' to reconcile the trust-anchor secret with the cluster state."},
    {"input": "Prometheus alert: PersistentVolume 'postgresql-pvc' is at 95% capacity.", "output": "Root Cause: WAL log accumulation due to high-write transaction load. Action: Scale the PVC capacity in the helm chart 'values.yaml' and trigger a rolling update of the database."},
    {"input": "Kubernetes Audit: Discovery of a pod running with 'privileged: true' outside of 'chaos-testing'.", "output": "Root Cause: Security Policy bypass. A manually applied manifest bypassed Kyverno. Action: Enforce 'disallow-privileged-containers' ClusterPolicy with 'Enforce' action and kill the non-compliant pod."},
    {"input": "Service Discovery Failure: frontend cannot resolve 'cartservice.default.svc.cluster.local'.", "output": "Root Cause: CoreDNS ConfigMap corruption during automated update. Action: Rollback the 'coredns' ConfigMap using the GitOps history and restart CoreDNS pods."},
    {"input": "Predictive Alert: Memory usage on 'shippingservice' is trending towards OOM in 4 hours.", "output": "Root Cause: Steady-state memory leak in the gRPC handler. Action: Trigger a proactive 'rollout restart' during off-peak hours to reset the heap and schedule a code-level memory profile."}
]

def extract_qa_from_markdown(content):
    """
    Heuristic: Extract Analysis (Input) and RCA (Output) from our markdown template.
    """
    input_text = ""
    output_text = ""
    
    # Extract "Evidence / Context" or "Alert Details"
    context_match = re.search(r"## (Alert Details|Evidence / Context)\n(.*?)\n##", content, re.DOTALL)
    if context_match:
        input_text = context_match.group(2).strip()
    
    # Extract "RCA" or "Analysis"
    rca_match = re.search(r"## (AI Analysis & RCA|Root Cause Analysis)\n(.*?)\n##", content, re.DOTALL)
    if rca_match:
        output_text = rca_match.group(2).strip()
    
    return input_text, output_text

def main():
    print(f"[*] Generating training dataset from {POST_MORTEMS_DIR} and Bootstrap Library...")
    dataset = BOOTSTRAP_LIBRARY.copy() # Start with expert knowledge
    
    if os.path.exists(POST_MORTEMS_DIR):
        for filename in os.listdir(POST_MORTEMS_DIR):
            if filename.endswith(".md"):
                with open(os.path.join(POST_MORTEMS_DIR, filename), "r") as f:
                    content = f.read()
                    inp, outp = extract_qa_from_markdown(content)
                    if inp and outp:
                        dataset.append({"input": inp[:1000], "output": outp[:1000]})
    else:
        print(f"⚠️ Warning: {POST_MORTEMS_DIR} not found. Using Bootstrap Library only.")
    
    if dataset:
        with open(OUTPUT_FILE, "w") as f:
            for entry in dataset:
                f.write(json.dumps(entry) + "\n")
        print(f"✅ Generated {len(dataset)} training examples in {OUTPUT_FILE}")
    else:
        print("❌ No valid training pairs found in post-mortems.")

if __name__ == "__main__":
    main()
