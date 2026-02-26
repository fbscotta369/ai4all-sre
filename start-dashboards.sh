#!/bin/bash

# Ensure KUBECONFIG is set locally for this script
export KUBECONFIG=~/.kube/config

# Retrieve Chaos Mesh Token proactively
CHAOS_TOKEN=$(kubectl get secret chaos-mesh-token -n default -o jsonpath='{.data.token}' | base64 --decode 2>/dev/null || echo "PENDING")

echo "Starting Port-Forwards for AI4ALL SRE Stack..."

# Array to keep track of background PIDs
PIDS=()

# Function to start a port forward and record its PID
start_port_forward() {
    local namespace=$1
    local service=$2
    local local_port=$3
    local remote_port=$4
    local name=$5

    echo "Forwarding $name to http://localhost:$local_port"
    kubectl port-forward svc/$service -n $namespace $local_port:$remote_port > /dev/null 2>&1 &
    PIDS+=($!)
}

# 1. ArgoCD
start_port_forward "argocd" "argocd-server" 8080 80 "ArgoCD Dashboard"

# 2. Grafana (Observability)
start_port_forward "observability" "kube-prometheus-grafana" 8082 80 "Grafana Dashboard"
# 3. GoAlert (Incident Management)
start_port_forward "incident-management" "goalert" 8083 80 "GoAlert Dashboard"

# 4. Online Boutique App (Target Application)
start_port_forward "online-boutique" "frontend" 8084 80 "Online Boutique App"

# 5. Chaos Mesh Dashboard
start_port_forward "chaos-testing" "chaos-dashboard" 2333 2333 "Chaos Mesh Dashboard"

# 6. Prometheus Dashboard
start_port_forward "observability" "kube-prometheus-kube-prome-prometheus" 9090 9090 "Prometheus Dashboard"

# 7. AlertManager Dashboard
start_port_forward "observability" "kube-prometheus-kube-prome-alertmanager" 9093 9093 "AlertManager Dashboard"

echo ""
echo "✅ All dashboards and apps are now accessible!"
echo "------------------------------------------------"
echo "Online Boutique: http://localhost:8084"
echo "ArgoCD:          http://localhost:8080"
echo "Grafana:         http://localhost:8082"
echo "GoAlert:         http://localhost:8083 (or http://goalert.local)"
echo "Chaos Mesh:      http://localhost:2333 (or http://chaos.local)"
echo "  ↳ Token:       $CHAOS_TOKEN"
echo "Prometheus:      http://localhost:9090"
echo "AlertManager:    http://localhost:9093"
echo "------------------------------------------------"
echo "Press Ctrl+C to stop all port-forwards."

# Wait for user interrupt
trap "echo 'Stopping all port-forwards...'; kill ${PIDS[*]}; exit 0" SIGINT SIGTERM
wait
