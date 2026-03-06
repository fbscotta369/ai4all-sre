#!/bin/bash

# AI4ALL-SRE End-to-End Test Automation 🧪
# FIX 10: Hardened lifecycle — idempotent pod creation, proper cleanup trap, 
#          unique run ID per execution, removed silent failure modes.

set -euo pipefail  # Strict mode: exit on error, undefined vars, pipe failures

# Formatting
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        AI4ALL-SRE Complete A-Z End-to-End Test Automation            ${NC}"
echo -e "${BLUE}======================================================================${NC}"

export KUBECONFIG=~/.kube/config

# FIX 10: Unique pod name per run prevents collision if previous run left residue
RUN_ID="e2e-tester-$(date +%s)"
TOTAL_TESTS=0; PASSED_TESTS=0; FAILED_TESTS=0
FAIL_LOG=""

# FIX 10: Proper cleanup trap — runs even if script exits early on error
cleanup() {
    echo -e "\n${YELLOW}>>> Cleaning up ephemeral test pod '${RUN_ID}'...${NC}"
    kubectl delete pod "${RUN_ID}" -n default --wait=false --ignore-not-found=true > /dev/null 2>&1 || true
    if [ "$FAILED_TESTS" -gt 0 ]; then
        echo -e "${RED}>>> Test run FAILED. ${FAILED_TESTS}/${TOTAL_TESTS} tests did not pass.${NC}"
        echo -e "${YELLOW}Failed tests:${NC}"
        echo -e "$FAIL_LOG"
        exit 1
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Helper: run a test and track result without swallowing failures
# ---------------------------------------------------------------------------
test_run() {
    local name=$1; local cmd=$2; local error_msg=${3:-"No detail provided"}
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -ne "  Testing ${name}... "
    if eval "${cmd}" > /dev/null 2>&1; then
        echo -e "[ ${GREEN}PASS${NC} ]"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "[ ${RED}FAIL${NC} ] — ${error_msg}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAIL_LOG="${FAIL_LOG}\n  - ${name}: ${error_msg}"
    fi
}

# ---------------------------------------------------------------------------
# Helper: curl test via ephemeral pod (set up once, used multiple times)
# ---------------------------------------------------------------------------
test_curl_pod() {
    local name=$1; local url=$2; local expected_code=$3; local error_msg=${4:-""}
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -ne "  Endpoint: ${name}... "
    local http_code
    http_code=$(kubectl exec -n default "${RUN_ID}" -- \
        curl -s --max-time 10 -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || echo "ERROR")
    if [ "${http_code}" = "${expected_code}" ]; then
        echo -e "[ ${GREEN}PASS${NC} ] (HTTP ${http_code})"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "[ ${RED}FAIL${NC} ] (got HTTP ${http_code}, want ${expected_code}) — ${error_msg}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAIL_LOG="${FAIL_LOG}\n  - ${name}: expected ${expected_code} got ${http_code}"
    fi
}

# ===========================================================================
echo -e "\n${BLUE}>>> Phase 1: Infrastructure & Core Components <<<${NC}"

test_run "Kubernetes APIServer Connectivity" "kubectl cluster-info" "Cannot connect to the cluster."
test_run "Cluster Nodes Ready" "kubectl get nodes | grep -wq Ready" "One or more nodes not Ready."

NAMESPACES=("argocd" "observability" "incident-management" "online-boutique" "chaos-testing" "vault" "ollama" "default" "linkerd" "kyverno")
for ns in "${NAMESPACES[@]}"; do
    test_run "Namespace '${ns}' exists" "kubectl get namespace ${ns}" "Namespace '${ns}' not found."
done

# ===========================================================================
echo -e "\n${BLUE}>>> Phase 2: Core Workloads Readiness <<<${NC}"

check_deployments() { test_run "Deployments in '${1}' Ready (30s)" \
    "kubectl wait --for=condition=available --timeout=30s deployment --all -n ${1}" \
    "Deployments in ${1} not available."; }

for ns in argocd observability incident-management chaos-testing vault ollama; do
    check_deployments "${ns}"
done
check_deployments "online-boutique"

test_run "Frontend Argo Rollout is Healthy" \
    "kubectl get rollout frontend -n online-boutique -o jsonpath='{.status.phase}' | grep -iq healthy" \
    "Frontend rollout not Healthy."

test_run "Linkerd Control Plane Ready" \
    "kubectl get deploy -n linkerd -o jsonpath='{.items[*].status.readyReplicas}' | tr ' ' '\n' | grep -v '^0$' | wc -l | grep -qv '^0$'" \
    "Linkerd control plane not ready."

test_run "Kyverno Webhook Active" \
    "kubectl get validatingwebhookconfigurations kyverno-resource-validating-webhook-cfg" \
    "Kyverno webhook not registered."

# ===========================================================================
echo -e "\n${BLUE}>>> Phase 3: Service Endpoint Validation <<<${NC}"
echo -n "  Deploying ephemeral curl pod '${RUN_ID}'... "

# FIX 10: Explicit readiness wait with timeout, fail-fast if pod cannot start
kubectl run "${RUN_ID}" --image=curlimages/curl:8.6.0 --restart=Never -n default \
    --labels="purpose=e2e-test" -- sleep 300 > /dev/null 2>&1
if ! kubectl wait --for=condition=ready pod/"${RUN_ID}" -n default --timeout=60s > /dev/null 2>&1; then
    echo -e "${RED}FAILED — curl pod did not start within 60s. Aborting endpoint tests.${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAIL_LOG="${FAIL_LOG}\n  - Curl pod startup timed out"
else
    echo -e "${GREEN}Ready${NC}"

    test_curl_pod "Online Boutique (Frontend)" "http://frontend.online-boutique.svc.cluster.local" "200" "Frontend not serving HTTP 200."
    test_curl_pod "ArgoCD UI" "http://argocd-server.argocd.svc.cluster.local" "200" "ArgoCD UI not responding."
    test_curl_pod "Grafana UI" "http://kube-prometheus-grafana.observability.svc.cluster.local" "200" "Grafana not responding."
    test_curl_pod "Prometheus UI" "http://kube-prometheus-kube-prome-prometheus.observability.svc.cluster.local:9090/-/healthy" "200" "Prometheus not healthy."
    test_curl_pod "GoAlert UI" "http://goalert.incident-management.svc.cluster.local" "200" "GoAlert not responding."
    test_curl_pod "Chaos Mesh UI" "http://chaos-dashboard.chaos-testing.svc.cluster.local:2333" "200" "Chaos Mesh dashboard not responding."
    test_curl_pod "Vault Health" "http://vault.vault.svc.cluster.local:8200/v1/sys/health" "200" "Vault not initialized/ready."
    test_curl_pod "Ollama API" "http://ollama.ollama.svc.cluster.local:11434/api/version" "200" "Ollama not responding."
    test_curl_pod "AI Agent Health" "http://ai-agent.observability.svc.cluster.local:8000/health" "200" "AI Agent not healthy."
fi

# ===========================================================================
echo -e "\n${BLUE}>>> Phase 4: Functional Checks <<<${NC}"

test_run "Behavioral Load Generator Running" \
    "kubectl get deployment behavioral-loadgen -n online-boutique" \
    "Load generator deployment not found."

test_run "Vault Seal Status" \
    "kubectl exec -n vault statefulset/vault -- vault status -format=json 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); sys.exit(0 if not d['sealed'] else 1)\"" \
    "Vault is sealed or exec failed."

test_run "Prometheus SLO Rules Loaded" \
    "kubectl exec -n observability -c prometheus statefulset/prometheus-kube-prometheus-prometheus -- \
     promtool query series '{__name__=\"frontend_success_rate_5m\"}' --url=http://localhost:9090 2>&1 | grep -q 'frontend'" \
    "SLO recording rule 'frontend_success_rate_5m' not found in Prometheus."

test_run "Kyverno Policy: disallow-privileged-containers Active" \
    "kubectl get clusterpolicy disallow-privileged-containers -o jsonpath='{.spec.validationFailureAction}' | grep -q Enforce" \
    "Kyverno privileged container policy not Enforced."

test_run "HPA: paymentservice-hpa Active" \
    "kubectl get hpa paymentservice-hpa -n online-boutique" \
    "PaymentService HPA not found."

test_run "NetworkPolicy: default-deny-all Active" \
    "kubectl get networkpolicy default-deny-all -n online-boutique" \
    "Default-deny NetworkPolicy not found in online-boutique."

# ===========================================================================
echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${BLUE}                        Test Summary Report                           ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "  Total  : ${TOTAL_TESTS}"
echo -e "  Passed : ${GREEN}${PASSED_TESTS}${NC}"
echo -e "  Failed : $([ "$FAILED_TESTS" -eq 0 ] && echo "${GREEN}0${NC}" || echo "${RED}${FAILED_TESTS}${NC}")"

if [ "$FAILED_TESTS" -eq 0 ]; then
    echo -e "${GREEN}>>> ALL TESTS PASSED — Lab is Fully Operational! <<<${NC}"
fi
# cleanup trap handles exit code
