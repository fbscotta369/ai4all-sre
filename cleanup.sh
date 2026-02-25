#!/bin/bash

# AI4ALL-SRE Cleanup Script 🧹
set -e

echo "Starting AI4ALL-SRE Laboratory Cleanup..."
echo "------------------------------------------------"

# 1. Terraform Destroy
echo "Destroying Infrastructure..."
terraform destroy -auto-approve

# 2. Namespace Final Cleanup (Optional but good practice)
echo "Ensuring namespaces are removed..."
kubectl delete namespace online-boutique observability incident-management chaos-testing argocd trivy-system --ignore-not-found

echo "------------------------------------------------"
echo "✅ Laboratory Cleanup Complete!"
echo "------------------------------------------------"
