#!/bin/bash
set -euo pipefail

# Check dependencies
require_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is required but not installed." >&2
        exit 1
    fi
}

require_command kubectl
require_command lsof
require_command fuser

# Ensure KUBECONFIG is set locally for this script
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster. Check KUBECONFIG." >&2
    exit 1
fi

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

    # Check for existing process on this port and kill it
    if lsof -i ":$local_port" -t &> /dev/null; then
        echo "[*] Port $local_port is busy. Releasing..."
        if fuser -k "$local_port/tcp" &> /dev/null; then
            sleep 1
        else
            echo "Warning: Could not kill process on port $local_port" >&2
        fi
    fi

    echo "Forwarding $name to http://localhost:$local_port"
    if kubectl port-forward "svc/$service" -n "$namespace" "$local_port:$remote_port" > /dev/null 2>&1 & then
        PIDS+=($!)
    else
        echo "Error: Failed to start port-forward for $name" >&2
        return 1
    fi
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

# 8. Docs Portal (Engineering Hub)
start_port_forward "docs-portal" "docs-portal" 8085 80 "Docs Portal"

# 9. Vault UI (Security & Secrets)
start_port_forward "vault" "vault" 8200 8200 "Vault UI"

# 10. Ollama API (AI Infrastructure)
start_port_forward "ollama" "ollama" 11434 11434 "Ollama API"

# 11. AI SRE Agent API
start_port_forward "observability" "ai-agent" 8000 80 "AI Agent API"

# 12. Loki API (Log Search)
start_port_forward "observability" "loki" 3100 3100 "Loki API"

# Function to cleanup PIDs on exit
cleanup() {
    echo "Stopping all port-forwards..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    exit 0
}

# Trap signals for clean exit
trap cleanup SIGINT SIGTERM

echo ""
echo "✅ All dashboards and apps are now accessible!"
echo "------------------------------------------------"
echo "Online Boutique: http://localhost:8084"
echo "ArgoCD:          http://localhost:8080"
echo "Grafana:         http://localhost:8082"
echo "GoAlert:         http://localhost:8083"
echo "Chaos Mesh:      http://localhost:2333"
echo "Prometheus:      http://localhost:9090"
echo "AlertManager:    http://localhost:9093"
echo "Docs Portal:     http://localhost:8085"
echo "Vault UI:        http://localhost:8200"
echo "Ollama API:      http://localhost:11434"
echo "AI Agent API:    http://localhost:8000"
echo "Loki API:        http://localhost:3100"
echo "------------------------------------------------"

# If running in a TTY, wait for user interrupt. If not (background/service), just wait.
if [ -t 0 ]; then
    echo "Press Ctrl+C to stop all port-forwards."
fi

wait
