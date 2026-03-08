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
python3 -m py_compile components/ai-agent/ai_agent.py

if command -v pylint &> /dev/null; then
    echo "[*] Running pylint on ai_agent.py..."
    pylint components/ai-agent/ai_agent.py --disable=C0114,C0116,C0115 || true
fi

# 2.5 Unit Tests
echo "[*] Running Python unit tests..."
export PYTHONPATH=$PYTHONPATH:$(pwd)/components/ai-agent:$(pwd)/components/loadgen:$(pwd)/scripts/internal
if command -v conda &> /dev/null && conda info --envs | grep -q "sre-ai-lab"; then
    conda run -n sre-ai-lab python3 -m unittest discover tests/
else
    python3 -m unittest discover tests/
fi

# 2.8 Shell Linting (ShellCheck)
if command -v shellcheck &> /dev/null; then
    echo "[*] Running shellcheck on shell scripts..."
    shellcheck scripts/*.sh *.sh ai-lab/*.sh
else
    echo "⚠️ Warning: shellcheck not found. Skipping shell linting."
fi

# 2.9 YAML Linting (Yamllint)
if command -v yamllint &> /dev/null; then
    echo "[*] Running yamllint on manifests and configs..."
    yamllint .
else
    echo "⚠️ Warning: yamllint not found. Skipping YAML linting."
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

if command -v checkov &> /dev/null; then
    echo "[*] Running checkov on infrastructure..."
    checkov -d . --framework terraform kubernetes || true
fi

# 4.5 Secret Scanning (gitleaks)
if command -v gitleaks &> /dev/null; then
    echo "[*] Running gitleaks to detect secret leaks..."
    gitleaks detect --source . -v || true
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

# 6. Proactive Cluster Health (OOM/Crash Detection)
echo "[*] checking for recent OOMKilled pods (last 30m)..."
if command -v jq &> /dev/null; then
    OOM_COUNT=$(kubectl get pods -A -o json | jq '.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason=="OOMKilled") | .metadata.name' | wc -l)
else
    echo "⚠️ Warning: jq not found. Falling back to grep for OOM detection..."
    OOM_COUNT=$(kubectl get pods -A -o json | grep -c "OOMKilled" || echo "0")
fi

if [ "$OOM_COUNT" -gt 0 ]; then
    echo "❌ Alert: $OOM_COUNT pods were OOMKilled recently. Check resource limits!"
else
    echo "✅ No recent OOMKills detected."
fi

# 7. Security Audit Status
echo "[*] Checking Trivy VulnerabilityReport status..."
REPORT_COUNT=$(kubectl get vulnerabilityreports -A --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$REPORT_COUNT" -gt 0 ]; then
    echo "✅ $REPORT_COUNT VulnerabilityReports found in cluster."
else
    echo "⚠️ Warning: No VulnerabilityReports found. Trivy might be failing to reconcile reports."
fi

# 8. AI Laboratory Verification
echo "[*] Checking AI Laboratory environment readiness..."
if command -v conda &> /dev/null; then
    if conda info --envs | grep -q "sre-ai-lab"; then
        echo "✅ AI Laboratory environment (sre-ai-lab) is present."
    else
        echo "⚠️ Warning: AI Laboratory environment (sre-ai-lab) not found. Run ./ai-lab/create-env.sh."
    fi
else
    echo "⚠️ Warning: Conda not in PATH. Skipping environment check."
fi

echo "------------------------------------------------"
echo "✅ Pipeline Validation Passed!"
echo "------------------------------------------------"
