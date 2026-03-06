#!/bin/bash

# AI4ALL-SRE End-to-End Test Automation 🧪
# This script performs a complete A-Z test of all components in the laboratory.

# Removed set -e to allow all tests to run even if some cluster operations fail.

# Formatting variables
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}        AI4ALL-SRE Complete A-Z End-to-End Test Automation            ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""

# Ensure KUBECONFIG is set locally for this script
export KUBECONFIG=~/.kube/config

# Variables
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Helper Functions
test_run() {
    local name=$1
    local cmd=$2
    local error_msg=$3

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -ne "Testing $name... "
    
    # Run the command and capture output
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "[ ${GREEN}PASS${NC} ]"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "[ ${RED}FAIL${NC} ]"
        echo -e "${YELLOW}  Detail: $error_msg${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "${BLUE}>>> Phase 1: Infrastructure & Core Components <<<${NC}"

# 1. Cluster Connectivity
test_run "Kubernetes APIServer Connectivity" \
    "kubectl cluster-info" \
    "Cannot connect to the Kubernetes cluster."

# 2. Nodes Readiness
test_run "Cluster Nodes Readiness" \
    "kubectl get nodes | grep -w Ready > /dev/null" \
    "One or more nodes are not in Ready state."

# 3. Namespaces Existence
NAMESPACES=("argocd" "observability" "incident-management" "online-boutique" "chaos-testing" "docs-portal" "vault" "ollama" "default")
for ns in "${NAMESPACES[@]}"; do
    test_run "Namespace '$ns' Exists" \
        "kubectl get namespace $ns" \
        "Namespace '$ns' not found."
done

echo ""
echo -e "${BLUE}>>> Phase 2: Core Workloads Readiness <<<${NC}"

# Helper to check deployments in a namespace
check_deployments() {
    local ns=$1
    local label=$2
    test_run "Deployments in '$ns' are Ready" \
        "kubectl wait --for=condition=available --timeout=30s deployment --all -n $ns" \
        "Failed waiting for deployments in $ns to become available."
}

# Helper to check statefulsets in a namespace
check_statefulsets() {
    local ns=$1
    test_run "StatefulSets in '$ns' are Ready" \
        "kubectl get sts -n $ns -o jsonpath='{.items[*].status.readyReplicas}' | grep -v '^$'" \
        "StatefulSets in $ns are not fully ready."
}

# 4. Workloads
check_deployments "argocd"
check_deployments "observability"
check_deployments "incident-management"
check_deployments "chaos-testing"
check_deployments "docs-portal"
check_deployments "vault"
check_deployments "ollama"

# Boutique uses Rollout for frontend, Deployment for others
check_deployments "online-boutique"
test_run "Boutique Frontend Rollout is Healthy" \
    "kubectl get rollout frontend -n online-boutique -o jsonpath='{.status.phase}' | grep -i 'Healthy'" \
    "Frontend rollout is not Healthy."

# StatefulSets (like Prometheus/Loki if applicable)
check_statefulsets "observability"

echo ""
echo -e "${BLUE}>>> Phase 3: Service Endpoint Validation (Internal Curl) <<<${NC}"

# For endpoint validation, we'll deploy a swift ephemeral pod to curl services internally.
echo -e "Deploying ephemeral curl pod for internal endpoint testing..."
kubectl run e2e-tester --image=curlimages/curl:latest --restart=Never -n default -- sleep 600 > /dev/null 2>&1
kubectl wait --for=condition=ready pod/e2e-tester -n default --timeout=60s > /dev/null 2>&1

test_curl_pod() {
    local name=$1
    local url=$2
    local expected_code=$3
    local error_msg=$4

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -ne "Testing Endpoint: $name... "
    
    # Exec curl in the pod
    local http_code=$(kubectl exec -n default e2e-tester -- curl -s -o /dev/null -w "%{http_code}" "$url" || echo "ERROR")
    
    if [ "$http_code" == "$expected_code" ]; then
        echo -e "[ ${GREEN}PASS${NC} ] (HTTP $http_code)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "[ ${RED}FAIL${NC} ] (HTTP $http_code)"
        echo -e "${YELLOW}  Detail: Expected HTTP $expected_code, but got $http_code from $url. $error_msg${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Note: Some internal services might redirect (302) or return 401 unauth, which is expected.
# We test for exactly that response code to confirm the service is alive and listening.

test_curl_pod "Online Boutique (Frontend)" "http://frontend.online-boutique.svc.cluster.local" "200" "Frontend not responding with 200 OK."
test_curl_pod "ArgoCD UI" "http://argocd-server.argocd.svc.cluster.local" "200" "ArgoCD UI not responding."
test_curl_pod "Grafana UI" "http://kube-prometheus-grafana.observability.svc.cluster.local" "200" "Grafana UI not responding." # Returns 302 login, maybe 200 depending on path. Root usually 200.
test_curl_pod "Prometheus UI" "http://kube-prometheus-kube-prome-prometheus.observability.svc.cluster.local:9090/graph" "200" "Prometheus UI not responding."
test_curl_pod "GoAlert UI" "http://goalert.incident-management.svc.cluster.local" "200" "GoAlert UI not responding."
test_curl_pod "Chaos Mesh UI" "http://chaos-dashboard.chaos-testing.svc.cluster.local:2333" "200" "Chaos Mesh UI not responding."
test_curl_pod "Docs Portal" "http://docs-portal.docs-portal.svc.cluster.local" "200" "Docs Portal not responding."
test_curl_pod "Vault API (Health)" "http://vault.vault.svc.cluster.local:8200/v1/sys/health" "200" "Vault Health endpoint not responding with 200 OK (uninitialized is 501, ready is 200). Adjust if expect 501." # Vault might return 501 if uninitialized. Adjusting to accept either below if needed.
test_curl_pod "Ollama API (Version)" "http://ollama.ollama.svc.cluster.local:11434/api/version" "200" "Ollama API not returning version info."
test_curl_pod "AI Agent API (Health)" "http://ai-agent.observability.svc.cluster.local:8000/health" "200" "AI Agent Health endpoint not responding."

echo -e "Cleaning up ephemeral curl pod..."
kubectl delete pod e2e-tester -n default > /dev/null 2>&1 || true

echo ""
echo -e "${BLUE}>>> Phase 4: Specific A-Z Functional Checks <<<${NC}"

# Check if behavioral loadgen is running
test_run "Behavioral Load Generator Job/CronJob" \
    "kubectl get cronjob behavioral-loadgen -n online-boutique" \
    "Load generator CronJob not found (Ensure it is deployed)."

# Check Vault initialization status via UI exec (Optional advanced check)
test_run "Vault Initialization Status" \
    "kubectl exec -n vault statefulset/vault -- vault status | grep -E 'Initialized.*(true|false)' > /dev/null" \
    "Could not determine Vault initialization status via exec."

echo ""
echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}                        Test Summary Report                           ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Total Tests : $TOTAL_TESTS"
echo -e "Passed      : ${GREEN}$PASSED_TESTS${NC}"

if [ "$FAILED_TESTS" -eq 0 ]; then
    echo -e "Failed      : ${GREEN}0${NC}"
    echo -e "${GREEN}>>> ALL TESTS PASSED SUCCESSFULLY! The Lab is Fully Operational! <<<${NC}"
    exit 0
else
    echo -e "Failed      : ${RED}$FAILED_TESTS${NC}"
    echo -e "${RED}>>> SOME TESTS FAILED! Please review the details above. <<<${NC}"
    exit 1
fi
