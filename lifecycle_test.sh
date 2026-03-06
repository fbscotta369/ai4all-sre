#!/bin/bash

# ============================================================
#  AI4ALL-SRE: Autonomous SRE Laboratory
#  LIFECYCLE TEST SCRIPT (Zero to Hero and Back Again) 🚀
# ============================================================
#  This script proves that the entire AI4ALL-SRE environment
#  is 100% reproducible through Infrastructure as Code (IaC).
#
#  Sequence:
#   1. Destroy existing lab completely.
#   2. Setup new lab completely.
#   3. Validate all workloads and endpoints (e2e_test.sh).
#   4. (Optional via flag) Destroy lab completely again.
# ============================================================

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
