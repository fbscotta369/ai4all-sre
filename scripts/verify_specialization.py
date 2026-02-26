#!/usr/bin/env python3
import requests
import json

OLLAMA_URL = "http://localhost:11434/api/generate"

SCENARIOS = [
    {
        "name": "Cascading Latency",
        "prompt": "High latency detected on frontend. Linkerd p99 shows 1.2s spike. CPU at 90%. No memory issues. Analyze and provide a technical RCA and Remediation command."
    },
    {
        "name": "GitOps Drift",
        "prompt": "ArgoCD shows synchronization failed for 'online-boutique'. Error: secret 'linkerd-trust-anchor' not found. Analyze and provide a technical RCA and Remediation command."
    }
]

def query_ollama(model, prompt):
    try:
        res = requests.post(OLLAMA_URL, json={"model": model, "prompt": prompt, "stream": False}, timeout=60)
        if res.status_code == 200:
            return res.json().get("response", "No response.")
        return f"Error: {res.status_code}"
    except Exception as e:
        return f"Exception: {e}"

def main():
    print("SRE-Kernel Specialization Verification (A/B Test)")
    print("------------------------------------------------")
    
    for scenario in SCENARIOS:
        print(f"\n[Scenario]: {scenario['name']}")
        print(f"Prompt: {scenario['prompt']}")
        
        print("\n--- BASE MODEL (llama3) ---")
        base_resp = query_ollama("llama3", scenario['prompt'])
        print(base_resp)
        
        print("\n--- SPECIALIZED KERNEL (sre-kernel) ---")
        kernel_resp = query_ollama("sre-kernel", scenario['prompt'])
        print(kernel_resp)
        
        print("\n" + "="*50)

if __name__ == "__main__":
    main()
