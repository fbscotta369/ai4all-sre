#!/bin/bash

# ============================================================
#  AI4ALL-SRE: Autonomous SRE Laboratory
#  LIFECYCLE TEST SCRIPT (Zero to Hero and Back Again) 🚀
# ============================================================
#  This script proves that the entire AI4ALL-SRE environment
#  is 100% reproducible through Infrastructure as Code (IaC).
#
#  Sequence:
#   1.[3/5] Cleaning up remaining namespaces and finalizers...
#   2. Setup new lab completely.
#   3. Validate all workloads and endpoints (e2e_test.sh).
#   4. (Optional via flag) Destroy lab completely again.
# ============================================================

# Ultra-aggressive cleanup for Helm, ArgoCD, finalizers, and CRDs
echo -e "${YELLOW}[CLEANUP] Purging existing lab resources...${NC}"

echo "Uninstalling all Helm releases..."
helm list -A | awk 'NR>1 {print $1, "-n", $2}' | xargs -L1 helm uninstall || true

NAMESPACES="argocd observability incident-management online-boutique chaos-testing vault trivy-system keda cert-manager linkerd linkerd-viz linkerd-jaeger kyverno ai-lab ollama minio"

echo "Clearing stale APIServices..."
kubectl delete apiservice v1beta1.external.metrics.k8s.io --force --grace-period=0 || true

echo "Force-deleting namespaced resources..."
for ns in $NAMESPACES; do
    kubectl delete networkpolicy,deployment,service,statefulset,configmap,secret --all -n "$ns" --force --grace-period=0 || true
done

for ns in $NAMESPACES; do
    if kubectl get namespace "$ns" &> /dev/null; then
        echo "Removing finalizers for $ns..."
        kubectl patch namespace "$ns" -p '{"spec":{"finalizers":[]}}' --type=merge || true
        kubectl delete namespace "$ns" --force --grace-period=0 --wait=false || true
    fi
done

echo "Removing ArgoCD applications and finalizers..."
kubectl get applications -A -o jsonpath='{.items[*].metadata.name}' | xargs -n1 kubectl patch application -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge || true
kubectl delete applications --all -A --force --grace-period=0 --wait=false || true

echo "Removing Cluster-scoped roles and bindings..."
kubectl get clusterrole,clusterrolebinding -o name | grep -E 'ai-agent|kyverno|argocd|trivy|keda|prometheus|loki|tempo' | xargs kubectl delete --force --grace-period=0 || true

echo "Removing CRDs..."
kubectl get crd -o name | grep -E 'argoproj|kyverno|coreos|aquasecurity|keda|cert-manager|linkerd|chaos-mesh|hashicorp' | xargs kubectl delete --force --grace-period=0 || true

echo "⏳ Waiting for namespaces to be fully removed..."
for ns in $NAMESPACES; do
    while kubectl get namespace "$ns" &> /dev/null; do
        echo -n "."
        sleep 2
    done
done
echo ""
echo "✅ Namespaces and Cluster resources cleaned up."

# Clear Terraform state
echo "Clearing Terraform state..."
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup || true

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}          AI4ALL-SRE ZERO-TO-HERO LIFECYCLE AUTOMATION            ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo ""

# Variables
TEARDOWN_AT_END=${1:-false}

# --- 1. Teardown Phase ---
echo -e "${YELLOW}[PHASE 1] Destroying any existing laboratory infrastructure...${NC}"
./destroy.sh -y
echo -e "${GREEN}✅ Phase 1 (Teardown) Complete.${NC}"
echo ""

# --- 2. Setup Phase ---
echo -e "${YELLOW}[PHASE 2] Provisioning full laboratory infrastructure from zero...${NC}"

# Hybrid Step: Provision mission-critical secrets and namespaces directly
# This avoids Terraform "already exists" conflicts for bootstrap resources.
./provision_agent.sh

# Hybrid state bridge: Import pre-provisioned or persistent resources into Terraform
echo "Bridging hybrid components into Terraform state..."
terraform init || true
terraform import module.platform.module.sre_kernel.kubernetes_namespace.observability observability || true
terraform import module.platform.module.sre_kernel.kubernetes_deployment.redis observability/redis || true
terraform import module.platform.module.sre_kernel.kubernetes_service.redis observability/redis || true
terraform import module.platform.module.sre_kernel.kubernetes_role_binding.keda_auth_reader_binding kube-system/keda-metrics-auth-reader || true

# Redirect input from /dev/null to ensure non-interactive execution
./setup.sh < /dev/null
echo -e "${GREEN}✅ Phase 2 (Provisioning) Complete.${NC}"
echo ""

# --- 3. Validation Phase ---
echo -e "${YELLOW}[PHASE 3] Executing A-to-Z End-to-End Test Suite...${NC}"
if ./e2e_test.sh; then
    echo -e "${GREEN}✅ Phase 3 (Validation) Complete - All tests passed!${NC}"
else
    echo -e "${RED}❌ Phase 3 (Validation) Failed - Some tests did not pass.${NC}"
    # Always exit here if validation fails, so we can inspect the cluster state
    exit 1
fi
echo ""

# --- 4. Final Teardown Phase ---
if [ "$TEARDOWN_AT_END" = "true" ] || [ "$TEARDOWN_AT_END" = "--teardown" ]; then
    echo -e "${YELLOW}[PHASE 4] Executing final teardown to leave a blank slate...${NC}"
    ./destroy.sh -y
    echo -e "${GREEN}✅ Phase 4 (Final Teardown) Complete.${NC}"
else
    echo -e "${BLUE}Skipping Phase 4 (Final Teardown). The validated lab is ready for use.${NC}"
    echo -e "${BLUE}To auto-teardown next time, run: ./lifecycle_test.sh --teardown${NC}"
fi

echo ""
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}          🎉 LIFECYCLE E2E TEST COMPLETED SUCCESSFULLY 🎉             ${NC}"
echo -e "${GREEN}======================================================================${NC}"
exit 0
