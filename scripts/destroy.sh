#!/bin/bash

# ============================================================
#  AI4ALL-SRE: Autonomous SRE Laboratory — DESTROY SCRIPT
#  Usage: ./destroy.sh
#
#  This script tears down the entire lab cleanly and in the
#  correct order so that `./setup.sh` can reproduce it
#  from scratch. It is safe to run at any time.
#
#  Recruiter note: Run this, then run ./setup.sh to
#  prove the entire infrastructure is 100% IaC-reproducible.
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AI4ALL-SRE  |  Laboratory Destroy Script  🗑️          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  This will destroy ALL lab infrastructure.${NC}"
echo -e "${YELLOW}   To recreate it, run: ./setup.sh${NC}"
echo ""

# ── Confirm (skip with -y flag) ─────────────────────────────
if [[ "$1" != "-y" ]]; then
    read -r -p "Are you sure? Type 'yes' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""
echo "------------------------------------------------"

# ── Step 1: Remove problematic resources ──────────────────
echo -e "${BLUE}[1/5] Removing active Chaos and Policy resources...${NC}"

# Remove finalizers from chaos resources BEFORE deleting them to prevent hangs
kubectl get iochaos,networkchaos,podchaos,stresschaos,schedule -n chaos-testing -o name 2>/dev/null | xargs -r kubectl patch -n chaos-testing --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true

# Now safely delete (with --wait=false just in case)
kubectl delete stresschaos --all -n chaos-testing --wait=false  2>/dev/null || true
kubectl delete networkchaos --all -n chaos-testing --wait=false  2>/dev/null || true
kubectl delete podchaos --all -n chaos-testing --wait=false      2>/dev/null || true
kubectl delete schedule --all -n chaos-testing --wait=false      2>/dev/null || true

# Pre-delete Linkerd policies via kubectl to avoid Terraform refresh hangs
kubectl delete server --all -n online-boutique --wait=false  2>/dev/null || true
kubectl delete serverauthorization --all -n online-boutique --wait=false  2>/dev/null || true

# Remove webhooks that block namespace deletion (e.g. Kyverno)
kubectl delete validatingwebhookconfigurations --all --wait=false 2>/dev/null || true
kubectl delete mutatingwebhookconfigurations --all --wait=false 2>/dev/null || true

echo -e "${GREEN}✅ Dynamic resources removed.${NC}"

# ── Step 2: Terraform Destroy ────────────────────────────────
echo ""
echo -e "${BLUE}[2/5] Running Terraform destroy (this may take a few minutes)...${NC}"

# CRITICAL FIX: If CRDs are missing, kubernetes_manifest fails to refresh.
# We manually remove them from state so Terraform doesn't try to validate them.
echo -e "  ${YELLOW}Cleansing strict Kubernetes manifests from state...${NC}"
STRICT_RESOURCES=(
  "kubernetes_manifest.productcatalog_server"
  "kubernetes_manifest.authz_frontend_to_productcatalog"
  "kubernetes_manifest.frontend_server"
  "kubernetes_manifest.authz_loadgen_to_frontend"
  "kubernetes_manifest.policy_block_critical_vulnerabilities"
)
for RES in "${STRICT_RESOURCES[@]}"; do
    terraform state rm "$RES" 2>/dev/null || true
done

# Terraform might fail if CRDs are missing, but that's okay, we force-clean in Step 3.
terraform destroy -auto-approve || echo -e "${YELLOW}⚠️  Terraform destroy encountered errors, continuing to force-cleanup...${NC}"
echo -e "${GREEN}✅ Terraform resources destroyed (or bypassed).${NC}"

# ── Step 3: Force-delete any stuck namespaces ────────────────
echo ""
echo -e "${BLUE}[3/5] Cleaning up remaining namespaces...${NC}"
NAMESPACES=(
    online-boutique
    observability
    incident-management
    chaos-testing
    linkerd
    argocd
    argo-rollouts
    kyverno
    trivy-system
    vault
    minio
    ollama
    keda
    ai-lab
)
for NS in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NS" &>/dev/null; then
        echo "  Cleaning resources inside namespace: $NS"
        # Delete typical resources first to prevent them from becoming orphaned
        kubectl delete all --all -n "$NS" --ignore-not-found --timeout=30s 2>/dev/null || true
        # Also clean up helm secrets which block termination
        kubectl delete secret,configmap,pvc,serviceaccount,role,rolebinding --all -n "$NS" --ignore-not-found --timeout=30s 2>/dev/null || true
        
        echo "  Deleting namespace API object: $NS"
        kubectl delete namespace "$NS" --ignore-not-found --timeout=60s || {
            echo -e "  ${YELLOW}⚠️  Force-removing finalizers on $NS...${NC}"
            kubectl get namespace "$NS" -o json \
                | python3 -c "import sys,json; d=json.load(sys.stdin); d['spec']['finalizers']=[]; print(json.dumps(d))" \
                | kubectl replace --raw "/api/v1/namespaces/$NS/finalize" -f - 2>/dev/null || true
        }
    fi
done
echo -e "${GREEN}✅ Namespaces cleaned up.${NC}"

# ── Step 4: Remove Linkerd CRDs ─────────────────────────────
echo ""
echo -e "${BLUE}[4/5] Removing Linkerd CRDs (if present)...${NC}"

# Remove finalizers from CRDs to prevent deletion hangs
kubectl get crds 2>/dev/null | grep "linkerd\|chaos-mesh\|kyverno\|vault" | awk '{print $1}' | xargs -r kubectl patch crd --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true

kubectl get crds 2>/dev/null \
    | grep "linkerd\|chaos-mesh\|kyverno\|vault" \
    | awk '{print $1}' \
    | xargs -r kubectl delete crd --ignore-not-found 2>/dev/null || true
echo -e "${GREEN}✅ CRDs removed.${NC}"

# ── Step 5: Clean Terraform state lock ──────────────────────
echo ""
echo -e "${BLUE}[5/5] Cleaning local Terraform state caches...${NC}"
if [ -f "backend.tf" ]; then
    echo -e "  ${YELLOW}Note: Remote backend detected. Local caches will be purged, but remote state history remains in S3.${NC}"
fi
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl.bak 2>/dev/null || true
echo -e "${GREEN}✅ State caches cleaned.${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Laboratory destroyed successfully!              ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  To recreate the entire lab from scratch, run:      ║${NC}"
echo -e "${GREEN}║     ./setup.sh                                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
