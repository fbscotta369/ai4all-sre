#!/bin/bash

# ============================================================
#  AI4ALL-SRE: Autonomous SRE Laboratory — PAUSE SCRIPT
#  Usage: ./pause.sh
#
#  Scales down all lab workloads to zero replicas to save
#  compute resources. kube-system is intentionally excluded.
#  Original replica counts are saved for resume.
#  To resume, run: ./resume.sh
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
echo -e "${BLUE}║  AI4ALL-SRE  |  Laboratory Pause Script  ⏸️           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  This will scale down ALL lab workloads to zero.${NC}"
echo -e "${YELLOW}   To resume, run: ./resume.sh${NC}"
echo ""

# ── Confirm (skip with -y flag) ─────────────────────────────
if [[ "${1:-}" != "-y" ]]; then
    read -r -p "Are you sure? Type 'yes' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""
echo "------------------------------------------------"

# ── Lab namespaces (same as destroy.sh — kube-system excluded) ──
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

# ── Step 0: Save current replica counts ────────────────────
echo -e "${BLUE}[0/3] Snapshotting current replica counts...${NC}"
> "$STATE_FILE"
echo "{" >> "$STATE_FILE"
echo '  "namespaces": {}' >> "$STATE_FILE"
echo "}" >> "$STATE_FILE"

snapshot_namespace() {
    local NS="$1"
    local TMP=$(mktemp)
    local COUNT=0

    for DEPLOY in $(kubectl get deployment -n "$NS" -o name 2>/dev/null); do
        local NAME="${DEPLOY##*/}"
        local REPLICAS=$(kubectl get "$DEPLOY" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        echo "  $NS/deployment/$NAME=$REPLICAS" >&2
        echo "$NS/deployment/$NAME=$REPLICAS" >> "$TMP"
        ((COUNT++))
    done
    for STS in $(kubectl get statefulset -n "$NS" -o name 2>/dev/null); do
        local NAME="${STS##*/}"
        local REPLICAS=$(kubectl get "$STS" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        echo "  $NS/statefulset/$NAME=$REPLICAS" >&2
        echo "$NS/statefulset/$NAME=$REPLICAS" >> "$TMP"
        ((COUNT++))
    done
    for DS in $(kubectl get daemonset -n "$NS" -o name 2>/dev/null); do
        local NAME="${DS##*/}"
        local REPLICAS=$(kubectl get "$DS" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        echo "  $NS/daemonset/$NAME=$REPLICAS" >&2
        echo "$NS/daemonset/$NAME=$REPLICAS" >> "$TMP"
        ((COUNT++))
    done
    for ROLLOUT in $(kubectl get rollout -n "$NS" -o name 2>/dev/null 2>/dev/null || true); do
        local NAME="${ROLLOUT##*/}"
        local REPLICAS=$(kubectl get "$ROLLOUT" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        echo "  $NS/rollout/$NAME=$REPLICAS" >&2
        echo "$NS/rollout/$NAME=$REPLICAS" >> "$TMP"
        ((COUNT++))
    done

    if [[ $COUNT -gt 0 ]]; then
        python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
with open('$TMP') as f:
    lines = [l.strip() for l in f if l.strip()]
ns_state = {}
for line in lines:
    parts = line.split('/', 2)
    if len(parts) == 3:
        _, kind, kv = parts
        kname = kind + '/' + kv.rsplit('=', 1)[0]
        kreplicas = int(kv.rsplit('=', 1)[1])
        if kname not in ns_state:
            ns_state[kname] = kreplicas
state['namespaces']['$NS'] = ns_state
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
"
    fi
    rm -f "$TMP"
}

for NS in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NS" &>/dev/null; then
        snapshot_namespace "$NS"
    fi
done
echo -e "${GREEN}✅ Snapshot saved to $STATE_FILE${NC}"

# ── Step 1: Cordon all nodes ────────────────────────────────
echo ""
echo -e "${BLUE}[1/3] Cordoning all nodes to prevent rescheduling...${NC}"
for NODE in $(kubectl get nodes -o name 2>/dev/null | cut -d/ -f2); do
    if kubectl cordon "$NODE" 2>/dev/null; then
        echo "  Cordoned: $NODE"
    fi
done
echo -e "${GREEN}✅ Nodes cordoned.${NC}"

# ── Step 2: Scale down all lab workloads ────────────────────
echo ""
echo -e "${BLUE}[2/3] Scaling down all lab workloads to zero...${NC}"

SCALED_COUNT=0
for NS in "${NAMESPACES[@]}"; do
    if ! kubectl get namespace "$NS" &>/dev/null; then
        echo -e "  ${YELLOW}Skipping $NS (namespace not found)${NC}"
        continue
    fi

    echo ""
    echo "  Namespace: $NS"

    for DEPLOY in $(kubectl get deployment -n "$NS" -o name 2>/dev/null); do
        kubectl scale "$DEPLOY" -n "$NS" --replicas=0 &>/dev/null
        echo "    Scaled ${DEPLOY##*/} → 0"
        ((SCALED_COUNT++))
    done
    for STS in $(kubectl get statefulset -n "$NS" -o name 2>/dev/null); do
        kubectl scale "$STS" -n "$NS" --replicas=0 &>/dev/null
        echo "    Scaled ${STS##*/} → 0"
        ((SCALED_COUNT++))
    done
    for DS in $(kubectl get daemonset -n "$NS" -o name 2>/dev/null); do
        kubectl scale "$DS" -n "$NS" --replicas=0 &>/dev/null
        echo "    Scaled ${DS##*/} → 0"
        ((SCALED_COUNT++))
    done
    for ROLLOUT in $(kubectl get rollout -n "$NS" -o name 2>/dev/null 2>/dev/null || true); do
        kubectl scale "$ROLLOUT" -n "$NS" --replicas=0 &>/dev/null
        echo "    Scaled ${ROLLOUT##*/} → 0"
        ((SCALED_COUNT++))
    done
done

# ── Step 3: Wait for pods to terminate ──────────────────────
echo ""
echo -e "${BLUE}[3/3] Waiting for pods to terminate (up to 60s)...${NC}"
for NS in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NS" &>/dev/null; then
        kubectl delete pod --all -n "$NS" --ignore-not-found --wait=false 2>/dev/null || true
    fi
done
sleep 5
for NS in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NS" &>/dev/null; then
        REMAINING=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | grep -v "Completed" | wc -l)
        if [[ "$REMAINING" -gt 0 ]]; then
            echo -e "  ${YELLOW}$NS: $REMAINING pods still terminating (will clean up on resume)${NC}"
        fi
    fi
done

echo ""
echo -e "${GREEN}✅ Scaled down $SCALED_COUNT workloads to zero.${NC}"
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Laboratory paused successfully!                  ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Compute resources are now freed.                    ║${NC}"
echo -e "${GREEN}║  PVCs and config are preserved.                      ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  To resume, run: ./resume.sh                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
