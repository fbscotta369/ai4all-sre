#!/bin/bash

# ============================================================
#  AI4ALL-SRE: Autonomous SRE Laboratory — RESUME SCRIPT
#  Usage: ./resume.sh
#
#  Restores lab workloads to their original replica counts
#  (from the snapshot saved by ./pause.sh).
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STATE_FILE="${HOME}/.ai4all-sre-pause-state.json"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AI4ALL-SRE  |  Laboratory Resume Script  ▶️            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}❌ No pause state found at $STATE_FILE${NC}"
    echo -e "${RED}   Run ./pause.sh first.${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  This will restore all lab workloads to their original replicas.${NC}"
echo ""

if [[ "${1:-}" != "-y" ]]; then
    read -r -p "Are you sure? Type 'yes' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""
echo "------------------------------------------------"

# ── Step 1: Uncordon all nodes ────────────────────────────────
echo -e "${BLUE}[1/2] Uncordoning all nodes...${NC}"
for NODE in $(kubectl get nodes -o name 2>/dev/null | cut -d/ -f2); do
    if kubectl uncordon "$NODE" 2>/dev/null; then
        echo "  Uncordoned: $NODE"
    fi
done
echo -e "${GREEN}✅ Nodes uncordoned.${NC}"

# ── Step 2: Restore replica counts ────────────────────────────
echo ""
echo -e "${BLUE}[2/2] Restoring workload replicas...${NC}"

RESTORED=0
SKIPPED=0

restore_workloads() {
    local NS="$1"
    if ! kubectl get namespace "$NS" &>/dev/null; then
        echo -e "  ${YELLOW}Namespace $NS not found — skipping${NC}"
        return
    fi

    echo ""
    echo "  Namespace: $NS"

    python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
ns_data = state.get('namespaces', {}).get('$NS', {})
if not ns_data:
    print('    (no workloads recorded)')
for key, count in ns_data.items():
    print(f'RESTORE|{NS}|{key}|{count}')
" 2>/dev/null | while IFS='|' read -r CMD NS_K KIND_NAME REPLICAS; do
        if [[ "$CMD" != "RESTORE" || -z "$KIND_NAME" ]]; then
            continue
        fi
        if [[ "$REPLICAS" == "(no workloads recorded)" || -z "$REPLICAS" ]]; then
            continue
        fi

        case "$KIND_NAME" in
            deployment/*)
                NAME="${KIND_NAME#deployment/}"
                if kubectl get deployment "$NAME" -n "$NS" &>/dev/null; then
                    kubectl scale deployment "$NAME" -n "$NS" --replicas="$REPLICAS" &>/dev/null
                    echo "    Restored deployment/$NAME → $REPLICAS"
                    ((RESTORED++))
                else
                    ((SKIPPED++))
                fi
                ;;
            statefulset/*)
                NAME="${KIND_NAME#statefulset/}"
                if kubectl get statefulset "$NAME" -n "$NS" &>/dev/null; then
                    kubectl scale statefulset "$NAME" -n "$NS" --replicas="$REPLICAS" &>/dev/null
                    echo "    Restored statefulset/$NAME → $REPLICAS"
                    ((RESTORED++))
                else
                    ((SKIPPED++))
                fi
                ;;
            daemonset/*)
                NAME="${KIND_NAME#daemonset/}"
                if kubectl get daemonset "$NAME" -n "$NS" &>/dev/null; then
                    kubectl scale daemonset "$NAME" -n "$NS" --replicas="$REPLICAS" &>/dev/null
                    echo "    Restored daemonset/$NAME → $REPLICAS"
                    ((RESTORED++))
                else
                    ((SKIPPED++))
                fi
                ;;
            rollout/*)
                NAME="${KIND_NAME#rollout/}"
                if kubectl get rollout "$NAME" -n "$NS" &>/dev/null; then
                    kubectl scale rollout "$NAME" -n "$NS" --replicas="$REPLICAS" &>/dev/null
                    echo "    Restored rollout/$NAME → $REPLICAS"
                    ((RESTORED++))
                else
                    ((SKIPPED++))
                fi
                ;;
        esac
    done
}

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
    docs-portal
)

for NS in "${NAMESPACES[@]}"; do
    restore_workloads "$NS"
done

echo ""
echo -e "${GREEN}✅ Restored $RESTORED workloads.${NC}"
if [[ "$SKIPPED" -gt 0 ]]; then
    echo -e "  ${YELLOW}Skipped $SKIPPED workloads (not found in cluster).${NC}"
fi
echo ""

# ── Cleanup: remove stale finalizers from paused chaos resources ──
echo -e "${BLUE}Cleaning up stale chaos resources...${NC}"
kubectl get iochaos,networkchaos,podchaos,stresschaos,schedule -n chaos-testing -o name 2>/dev/null | xargs -r kubectl patch -n chaos-testing --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Laboratory resumed successfully!               ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Workloads are scaling back up.                     ║${NC}"
echo -e "${GREEN}║  Check status with: kubectl get pods -A             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
