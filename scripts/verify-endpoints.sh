#!/bin/bash

# AI4ALL-SRE Endpoint Verification Tool 🩺
# Verifies that all local port-forwards are active and responding.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting AI4ALL-SRE Endpoint Verification...${NC}"
echo "------------------------------------------------"
printf "%-25s %-15s %-10s %-10s\n" "Endpoint" "Port" "Process" "HTTP"
echo "------------------------------------------------"

check_endpoint() {
    local name=$1
    local port=$2
    local url=$3
    local proc_status="${RED}DOWN${NC}"
    local http_status="${RED}FAIL${NC}"

    # 1. Process Check (kubectl port-forward)
    if ps aux | grep "kubectl port-forward" | grep ":$port" &> /dev/null; then
        proc_status="${GREEN}UP${NC}"
    fi

    # 2. HTTP Check
    # We use -L to follow redirects (common for auth/SSO)
    local code=$(curl -s -L -o /dev/null -w "%{http_code}" --connect-timeout 2 "$url")
    if [[ "$code" == "200" ]] || [[ "$code" == "302" ]] || [[ "$code" == "301" ]] || [[ "$code" == "401" ]]; then
        # 401 is considered "reachable" but requiring auth (e.g., ArgoCD/Vault)
        http_status="${GREEN}OK ($code)${NC}"
    else
        http_status="${RED}ERR ($code)${NC}"
    fi

    printf "%-25s %-15s %-10b %-10b\n" "$name" "$port" "$proc_status" "$http_status"
}

# List of endpoints to check
check_endpoint "ArgoCD" "8080" "http://localhost:8080"
check_endpoint "Grafana" "8082" "http://localhost:8082"
check_endpoint "GoAlert" "8083" "http://localhost:8083"
check_endpoint "Online Boutique" "8084" "http://localhost:8084"
check_endpoint "Chaos Mesh" "2333" "http://localhost:2333"
check_endpoint "Prometheus" "9090" "http://localhost:9090"
check_endpoint "AlertManager" "9093" "http://localhost:9093"
check_endpoint "Docs Portal" "8085" "http://localhost:8085"
check_endpoint "Vault UI" "8200" "http://localhost:8200"
check_endpoint "Ollama API" "11434" "http://localhost:11434"
check_endpoint "AI Agent API" "8000" "http://localhost:8000"
check_endpoint "Loki API" "3100" "http://localhost:3100"

echo "------------------------------------------------"
echo -e "${YELLOW}Verification Complete.${NC}"
