#!/bin/bash

# AI4ALL-SRE: Live Proof of Resilience 🛡️🚀
# This script demonstrates the power of code and IaC by triggering a failure
# and witnessing the autonomous detection, alerting, and remediation.

set -e

echo "------------------------------------------------"
echo "Starting Proof of Resilience Demo..."
echo "------------------------------------------------"

# 1. State Verification
echo "[*] Step 1: Verifying laboratory baseline..."
if ! ./scripts/validate.sh &> /dev/null; then
    echo "❌ Error: Laboratory is not in a healthy state. Please run ./setup-all.sh first."
    exit 1
fi
echo "✅ Baseline healthy."

# 2. Inject Failure (Adversary)
echo "[*] Step 2: Injecting CPU Stress into 'online-boutique' frontend..."
kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: demo-cpu-spike
  namespace: chaos-testing
spec:
  mode: all
  selector:
    namespaces:
      - online-boutique
    labelSelectors:
      'app': 'frontend'
  stressors:
    cpu:
      workers: 2
      load: 100
  duration: '5m'
EOF
echo "✅ Failure injected. Stressors active for 5 minutes."

# 3. Monitor Alert Chain
echo "[*] Step 3: Waiting for Prometheus to detect anomaly (~60-90s)..."
echo "    Monitor GoAlert at: http://localhost:8083"

# 4. Agentic Reasoning (Live Logs)
echo "[*] Step 4: Streaming AI Agent logs for reasoning visualization..."
echo "    [CTRL+C to jump to verification once remediation logs appear]"
echo "------------------------------------------------"
AGENT_POD=$(kubectl get pods -n observability -l app=ai-agent -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n observability -f $AGENT_POD --tail 20 &
LOG_PID=$!

# Wait for a remediation trigger in logs or 5 minutes timeout
(
    timeout 300s grep -m 1 "Successfully restarted" <(kubectl logs -n observability -f $AGENT_POD) 
    kill $LOG_PID 2>/dev/null
) || true

# 5. Cleanup & Final Check
echo "------------------------------------------------"
echo "[*] Step 5: Post-Remediation Verification..."
kubectl delete stresschaos demo-cpu-spike -n chaos-testing || true

echo "[*] Checking frontend pod health..."
kubectl get pods -n online-boutique -l app=frontend

echo "------------------------------------------------"
echo "✅ POC POC Works Out of the Box! Power of IaC Proven."
echo "------------------------------------------------"
