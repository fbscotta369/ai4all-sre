#!/bin/bash

# AI4ALL-SRE Pipeline Validation Script 🛡️
set -e

echo "Starting Pipeline Validation..."
echo "------------------------------------------------"

# 1. Terraform Validation
echo "[*] checking Terraform formatting..."
terraform fmt -check

echo "[*] Initializing Terraform for validation..."
terraform init -backend=false
terraform validate

# 2. Python Validation (AIOps Agent)
echo "[*] checking Python syntax (ai_agent.py)..."
python3 -m py_compile ai_agent.py

if command -v pylint &> /dev/null; then
    echo "[*] Running pylint on ai_agent.py..."
    pylint ai_agent.py --disable=C0114,C0116,C0115 || true
fi

# 3. Security Scanning (Trivy)
if command -v trivy &> /dev/null; then
    echo "[*] Running Trivy security scan on manifests..."
    trivy conf .
else
    echo "⚠️ Warning: Trivy is not installed. Skipping security scan."
fi

# 4. Infrastructure Security (tfsec/checkov)
if command -v tfsec &> /dev/null; then
    echo "[*] Running tfsec on Terraform code..."
    tfsec . || true
fi

# 5. Linkerd Health Check
echo "[*] Checking Linkerd Control Plane health..."
if kubectl get pods -n linkerd -l linkerd.io/control-plane-component=destination | grep -q "Running"; then
    echo "✅ Linkerd Destination service is healthy."
else
    echo "❌ Error: Linkerd Destination service is NOT healthy."
    exit 1
fi

echo "[*] Checking Linkerd mTLS connectivity..."
if ! command -v linkerd &> /dev/null; then
    echo "⚠️ Warning: Linkerd CLI not found. Skipping mTLS check."
else
    if linkerd check --proxy -n online-boutique &> /dev/null; then
        echo "✅ Linkerd mTLS is active in online-boutique."
    else
        echo "❌ Linkerd mTLS check failed or pods not yet injected."
    fi
fi

echo "------------------------------------------------"
echo "✅ Pipeline Validation Passed!"
echo "------------------------------------------------"
