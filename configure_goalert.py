import requests
import json
import os
import sys

# GoAlert Configuration Automation Script
# This script uses the GoAlert GraphQL API to set up the internal state.

GOALERT_URL = os.getenv("GOALERT_URL", "http://goalert.incident-management.svc.cluster.local")
ADMIN_TOKEN = os.getenv("ADMIN_TOKEN", "") # Use a pre-generated token if available, or handle auth

def query(q, variables=None):
    res = requests.post(
        f"{GOALERT_URL}/api/graphql",
        json={'query': q, 'variables': variables},
        headers={'Authorization': f'Bearer {ADMIN_TOKEN}'} if ADMIN_TOKEN else {}
    )
    if res.status_code != 200:
        print(f"Error: {res.text}")
        return None
    return res.json()

def main():
    print("[*] Starting GoAlert IaC Configuration...")
    
    # 1. Create Escalation Policy
    print("[*] Creating Escalation Policy: 'SRE-Critical'...")
    ep_mutation = """
    mutation ($input: CreateEscalationPolicyInput!) {
        createEscalationPolicy(input: $input) {
            id
        }
    }
    """
    ep_input = {
        "input": {
            "name": "SRE-Critical",
            "description": "Critical alerts for the SRE lab"
        }
    }
    ep_res = query(ep_mutation, ep_input)
    if not ep_res: return
    ep_id = ep_res['data']['createEscalationPolicy']['id']
    print(f"[+] Escalation Policy created: {ep_id}")

    # 2. Create Service
    print("[*] Creating Service: 'Online-Boutique'...")
    svc_mutation = """
    mutation ($input: CreateServiceInput!) {
        createService(input: $input) {
            id
        }
    }
    """
    svc_input = {
        "input": {
            "name": "Online-Boutique",
            "description": "Main microservices demo application",
            "escalationPolicyID": ep_id
        }
    }
    svc_res = query(svc_mutation, svc_input)
    if not svc_res: return
    svc_id = svc_res['data']['createService']['id']
    print(f"[+] Service created: {svc_id}")

    # 3. Add Integration Key (Generic)
    print("[*] Adding AlertManager Integration Key...")
    key_mutation = """
    mutation ($input: CreateIntegrationKeyInput!) {
        createIntegrationKey(input: $input) {
            id
            href
        }
    }
    """
    key_input = {
        "input": {
            "serviceID": svc_id,
            "type": "generic",
            "name": "AlertManager"
        }
    }
    key_res = query(key_mutation, key_input)
    if not key_res: return
    key_url = key_res['data']['createIntegrationKey']['href']
    print(f"[+] Integration Key created. URL: {key_url}")

    # Output the URL for AlertManager config (this should be captured or stored)
    with open("/tmp/goalert_integration_url", "w") as f:
        f.write(key_url)

    print("[+] GoAlert internal configuration complete.")

if __name__ == "__main__":
    main()
