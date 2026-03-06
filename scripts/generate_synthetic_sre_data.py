#!/usr/bin/env python3
import json
import random
import os

# Configuration
OUTPUT_FILE = "ai-lab/fine-tuning/dataset_generated.jsonl"
NUM_EXAMPLES = 550

SERVICES = [
    "frontend", "cartservice", "checkoutservice", "currencyservice", 
    "emailservice", "paymentservice", "productcatalogservice", 
    "recommendationservice", "shippingservice", "adservice"
]

NAMESPACES = ["online-boutique", "default"]

SCENARIOS = [
    {
        "type": "CPU Saturation",
        "input_templates": [
            "High CPU usage on {service}. Current utilization at {val}%.",
            "Prometheus Alert: {service} CPU usage > {val}% in {namespace}.",
            "{service} is throttling due to CPU limits. Usage: {val}%."
        ],
        "output_templates": [
            "Root Cause: Resource exhaustion. The {service} pod is hitting its CPU limits under high load. Action: SCALE DEPLOYMENT {service} IN {namespace} TO {count}",
            "Root Cause: CPU spike in {service}. Likely due to expensive request processing. Action: RESTART DEPLOYMENT {service} IN {namespace}"
        ]
    },
    {
        "type": "Memory Leak / OOM",
        "input_templates": [
            "{service} in {namespace} is showing a steady memory increase. Current: {val}MB.",
            "Predictive Alert: {service} will OOM in {val} minutes.",
            "Pod {service} restarted multiple times. Last state: OOMKilled."
        ],
        "output_templates": [
            "Root Cause: Memory leak in {service} gRPC handler. Action: RESTART DEPLOYMENT {service} IN {namespace}",
            "Root Cause: Insufficient memory limit for {service}. Action: SCALE DEPLOYMENT {service} IN {namespace} TO {count}"
        ]
    },
    {
        "type": "Network Latency",
        "input_templates": [
            "Linkerd reports p99 latency spike on {service}: {val}ms.",
            "Increased error rate (5xx) on {service} in {namespace}.",
            "Connection timeouts between frontend and {service}."
        ],
        "output_templates": [
            "Root Cause: Downstream service {service} is slow or unresponsive. Action: RESTART DEPLOYMENT {service} IN {namespace}",
            "Root Cause: Network mesh congestion affecting {service}. Action: RESTART DEPLOYMENT {service} IN {namespace}"
        ]
    },
    {
        "type": "GitOps / Sync",
        "input_templates": [
            "ArgoCD Sync Failed for {service}. Error: {val}.",
            "GitOps Drift detected in {namespace} for {service}.",
            "ConfigMap mismatch for {service} against Git source."
        ],
        "output_templates": [
            "Root Cause: Desired state mismatch in GitOps for {service}. Action: RESTART DEPLOYMENT {service} IN {namespace}",
            "Root Cause: Manual change bypassed ArgoCD for {service}. Action: RESTART DEPLOYMENT {service} IN {namespace}"
        ]
    }
]

def generate_data():
    dataset = []
    
    # Add some manual "Expert" seeds from existing generator to maintain quality
    seeds = [
        {"input": "High latency detected on frontend. Linkerd p99 shows 1.2s spike. CPU at 90%. No memory issues.", "output": "Root Cause: Ingress-Nginx buffering saturated due to unoptimized sysctl 'fs.inotify.max_user_instances'. Action: Increase inotify limits and restart frontend pods to clear buffer cache."},
        {"input": "ArgoCD shows synchronization failed for 'online-boutique'. Error: secret 'linkerd-trust-anchor' not found.", "output": "Root Cause: GitOps Drift. The trust anchor was manually rotated but the Terraform state was not updated. Action: Run 'terraform apply' to reconcile the trust-anchor secret with the cluster state."},
        {"input": "Prometheus alert: PersistentVolume 'postgresql-pvc' is at 95% capacity.", "output": "Root Cause: WAL log accumulation due to high-write transaction load. Action: Scale the PVC capacity in the helm chart 'values.yaml' and trigger a rolling update of the database."},
    ]
    dataset.extend(seeds)

    for _ in range(NUM_EXAMPLES - len(seeds)):
        scenario = random.choice(SCENARIOS)
        service = random.choice(SERVICES)
        namespace = random.choice(NAMESPACES)
        
        if scenario["type"] == "CPU Saturation":
            val = random.randint(85, 99)
        elif scenario["type"] == "Memory Leak / OOM":
            val = random.randint(10, 120)
        elif scenario["type"] == "Network Latency":
            val = random.randint(500, 3000)
        else:
            val = "Unknown synchronization error"

        input_text = random.choice(scenario["input_templates"]).format(
            service=service, namespace=namespace, val=val
        )
        
        count = random.randint(3, 10)
        output_text = random.choice(scenario["output_templates"]).format(
            service=service, namespace=namespace, count=count
        )
        
        dataset.append({"input": input_text, "output": output_text})

    # Shuffle to mix seeds and generated data
    random.shuffle(dataset)
    
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        for entry in dataset:
            f.write(json.dumps(entry) + "\n")
            
    print(f"✅ Generated {len(dataset)} examples in {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_data()
