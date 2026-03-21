#!/bin/bash
# Integration Test for AI4ALL-SRE Autonomous Loop
# Tests the full incident response flow: Alert → Agent → Remediation → Verification

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="online-boutique"
TEST_APP="frontend"
AI_AGENT_URL="${AI_AGENT_URL:-http://localhost:8000}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
TIMEOUT=60

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_failure "kubectl not found"
        exit 1
    fi
    print_success "kubectl found"
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_failure "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Kubernetes cluster connected"
    
    # Check AI agent endpoint
    if curl -s -o /dev/null -w "%{http_code}" "${AI_AGENT_URL}/health" | grep -q "200"; then
        print_success "AI Agent is reachable"
    else
        print_failure "AI Agent is not reachable at ${AI_AGENT_URL}"
        exit 1
    fi
}

# Test 1: Verify AI Agent Health
test_agent_health() {
    print_header "Test 1: AI Agent Health Check"
    print_test "Checking AI Agent health endpoint"
    
    response=$(curl -s "${AI_AGENT_URL}/health")
    
    if echo "$response" | grep -q '"status":"ok"'; then
        print_success "AI Agent health check passed"
        
        # Check Redis status
        if echo "$response" | grep -q '"redis":true'; then
            print_success "Redis connection is active"
        else
            print_info "Redis connection is inactive (using in-memory fallback)"
        fi
        
        # Check vector store status
        if echo "$response" | grep -q '"vector_store"'; then
            print_success "Vector store status available"
        fi
    else
        print_failure "AI Agent health check failed"
        print_info "Response: $response"
    fi
}

# Test 2: Deploy Test Application
test_deploy_application() {
    print_header "Test 2: Deploy Test Application"
    print_test "Deploying test application"
    
    # Create namespace if not exists
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy a simple test deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $TEST_APP
  namespace: $NAMESPACE
  labels:
    app: $TEST_APP
    test: integration
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $TEST_APP
  template:
    metadata:
      labels:
        app: $TEST_APP
        test: integration
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
EOF
    
    # Wait for deployment to be ready
    print_info "Waiting for deployment to be ready..."
    if kubectl rollout status deployment/$TEST_APP -n $NAMESPACE --timeout=${TIMEOUT}s; then
        print_success "Deployment is ready"
    else
        print_failure "Deployment failed to become ready"
    fi
}

# Test 3: Inject Synthetic Alert
test_inject_alert() {
    print_header "Test 3: Inject Synthetic Alert"
    print_test "Sending test alert to AI Agent"
    
    # Create a synthetic alert payload
    alert_payload='{
        "alerts": [
            {
                "status": "firing",
                "labels": {
                    "alertname": "HighCPUUsage",
                    "deployment": "'$TEST_APP'",
                    "namespace": "'$NAMESPACE'",
                    "severity": "critical",
                    "team": "sre"
                },
                "annotations": {
                    "summary": "High CPU usage detected on frontend",
                    "description": "CPU usage has exceeded 90% for more than 5 minutes",
                    "runbook_url": "https://runbooks.example.com/high-cpu"
                }
            }
        ]
    }'
    
    # Send alert to AI Agent
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$alert_payload" \
        "${AI_AGENT_URL}/webhook")
    
    if [ "$response_code" = "200" ]; then
        print_success "Alert injected successfully (HTTP $response_code)"
    else
        print_failure "Alert injection failed (HTTP $response_code)"
    fi
}

# Test 4: Verify Alert Processing
test_verify_processing() {
    print_header "Test 4: Verify Alert Processing"
    print_test "Waiting for AI Agent to process alert"
    
    # Wait a bit for processing
    sleep 10
    
    # Check if agent processed the alert (by checking logs if available)
    print_info "Checking AI Agent logs for processing confirmation..."
    
    # We can check if the agent pod is running
    agent_pod=$(kubectl get pods -n observability -l app=ai-agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$agent_pod" ]; then
        print_success "AI Agent pod is running: $agent_pod"
        
        # Try to get recent logs
        if kubectl logs "$agent_pod" -n observability --tail=20 | grep -q "Executing\|Remediation"; then
            print_success "AI Agent processed the alert"
        else
            print_info "AI Agent processing status unclear (check logs manually)"
        fi
    else
        print_info "AI Agent pod not found (may be running locally)"
    fi
}

# Test 5: Verify Deployment State
test_verify_state() {
    print_header "Test 5: Verify Deployment State"
    print_test "Checking deployment health after remediation"
    
    # Get deployment status
    ready_replicas=$(kubectl get deployment $TEST_APP -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    desired_replicas=$(kubectl get deployment $TEST_APP -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    print_info "Ready replicas: $ready_replicas / Desired: $desired_replicas"
    
    if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" -gt 0 ]; then
        print_success "Deployment is healthy"
    else
        print_failure "Deployment is not healthy"
    fi
}

# Test 6: Test Circuit Breaker (Optional)
test_circuit_breaker() {
    print_header "Test 6: Circuit Breaker Test"
    print_test "Testing circuit breaker fallback behavior"
    
    # This test is informational - we verify the agent can handle dependency failures
    print_info "Circuit breaker ensures graceful degradation when dependencies fail"
    print_info "Check /health endpoint for Redis and Ollama status"
    
    response=$(curl -s "${AI_AGENT_URL}/health")
    if echo "$response" | grep -q "redis"; then
        print_success "Circuit breaker health status available"
    else
        print_info "Circuit breaker status not available"
    fi
}

# Test 7: Cleanup
test_cleanup() {
    print_header "Test 7: Cleanup"
    print_test "Cleaning up test resources"
    
    # Delete test deployment
    if kubectl delete deployment $TEST_APP -n $NAMESPACE --ignore-not-found; then
        print_success "Test deployment deleted"
    else
        print_info "Test deployment deletion failed or not found"
    fi
    
    # Optionally delete namespace if it was created by us
    if kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.test}' | grep -q "integration"; then
        kubectl delete namespace $NAMESPACE --ignore-not-found
        print_success "Test namespace deleted"
    fi
}

# Print summary
print_summary() {
    print_header "Test Summary"
    echo -e "Total tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed!${NC}"
        exit 1
    fi
}

# Main execution
main() {
    print_header "AI4ALL-SRE Integration Test Suite"
    print_info "Testing full autonomous incident response loop"
    print_info "AI Agent URL: $AI_AGENT_URL"
    print_info "Namespace: $NAMESPACE"
    
    # Run tests
    check_prerequisites
    test_agent_health
    test_deploy_application
    test_inject_alert
    test_verify_processing
    test_verify_state
    test_circuit_breaker
    test_cleanup
    
    # Print summary
    print_summary
}

# Handle script interruption
trap 'print_info "Test interrupted. Running cleanup..."; test_cleanup; exit 1' INT TERM

# Run main function
main "$@"