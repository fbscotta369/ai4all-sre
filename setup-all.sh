#!/bin/bash

# AI4ALL-SRE Master Setup Script 🚀
set -e

echo "Starting AI4ALL-SRE Laboratory Setup..."
echo "------------------------------------------------"

# 1. Dependency Checks
check_dep() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ Error: $1 is not installed."
        exit 1
    fi
    echo "✅ $1 is installed."
}

check_dep "kubectl"
check_dep "terraform"
check_dep "helm"
check_dep "ollama"

# 2. Ollama Llama3 Check
if ! ollama list | grep -q "llama3"; then
    echo "⚠️ Warning: llama3 model not found in Ollama. Pulling it now..."
    ollama pull llama3
else
    echo "✅ Ollama llama3 model is available."
fi

# 3. K3s / Kubernetes Context Check
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster."
    exit 1
fi
echo "✅ Kubernetes cluster is reachable."

# 4. Terraform Initialization
echo "------------------------------------------------"
echo "Initializing Terraform..."
terraform init

# 5. Terraform Apply
echo "Applying Infrastructure..."
terraform apply -auto-approve

echo "------------------------------------------------"
echo "✅ Laboratory Setup Complete!"
echo "------------------------------------------------"
echo "To access dashboards, run: ./start-dashboards.sh"
echo "To start the AIOps agent, run: python3 ai_agent.py"
echo "------------------------------------------------"
