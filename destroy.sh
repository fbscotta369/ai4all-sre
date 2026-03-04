#!/bin/bash

# ============================================================
#  AI4ALL-SRE: Autonomous SRE Laboratory — DESTROY SCRIPT
#  Usage: ./destroy.sh
#
#  This script tears down the entire lab cleanly and in the
#  correct order so that `./setup-all.sh` can reproduce it
#  from scratch. It is safe to run at any time.
#
#  Recruiter note: Run this, then run ./setup-all.sh to
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
echo -e "${YELLOW}   To recreate it, run: ./setup-all.sh${NC}"
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

# ── Step 1: Remove active Chaos experiments ──────────────────
echo -e "${BLUE}[1/5] Removing active Chaos experiments...${NC}"
kubectl delete stresschaos --all -n chaos-testing   2>/dev/null || true
kubectl delete networkchaos --all -n chaos-testing  2>/dev/null || true
kubectl delete podchaos --all -n chaos-testing      2>/dev/null || true
kubectl delete schedule --all -n chaos-testing      2>/dev/null || true
echo -e "${GREEN}✅ Chaos experiments removed.${NC}"

# ── Step 2: Terraform Destroy ────────────────────────────────
echo ""
echo -e "${BLUE}[2/5] Running Terraform destroy (this may take a few minutes)...${NC}"
terraform destroy -auto-approve
echo -e "${GREEN}✅ Terraform resources destroyed.${NC}"

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
kubectl get crds 2>/dev/null \
    | grep "linkerd\|chaos-mesh\|kyverno" \
    | awk '{print $1}' \
    | xargs kubectl delete crd --ignore-not-found 2>/dev/null || true
echo -e "${GREEN}✅ CRDs removed.${NC}"

# ── Step 5: Clean Terraform state lock ──────────────────────
echo ""
echo -e "${BLUE}[5/5] Cleaning local Terraform state...${NC}"
rm -f .terraform.lock.hcl.bak terraform.tfstate.backup 2>/dev/null || true
echo -e "${GREEN}✅ State cleaned.${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Laboratory destroyed successfully!              ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  To recreate the entire lab from scratch, run:      ║${NC}"
echo -e "${GREEN}║     ./setup-all.sh                                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
