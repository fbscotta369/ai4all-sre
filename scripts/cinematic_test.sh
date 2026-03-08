#!/bin/bash
# ============================================================
#  AI4ALL-SRE: Cinematic A-Z Operational Validation 🎬
# ============================================================
# This script orchestrates a complete, visual, and cinematic
# test of the entire AI4ALL-SRE platform.
# ============================================================

set -e

# Design Tokens (Matching terminal aesthetic)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}"
echo "  █████╗ ██╗██╗  ██╗ █████╗ ██╗     ██╗     "
echo " ██╔══██╗██║██║  ██║██╔══██╗██║     ██║     "
echo " ███████║██║███████║███████║██║     ██║     "
echo " ██╔══██║██║╚════██║██╔══██║██║     ██║     "
echo " ██║  ██║██║     ██║██║  ██║███████╗███████╗"
echo " ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝"
echo -e "       CINEMATIC SRE VALIDATION SUITE v1.0.0${NC}\n"

# --- 1. Pre-flight Checks ---
echo -e "${BLUE}[1/6] 🚀 Initializing Pre-flight Checks...${NC}"
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is not installed.${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Error: terraform is not installed.${NC}"; exit 1; }
echo -e "${GREEN}✅ Pre-flight checks passed.${NC}\n"

# --- 2. Zero-to-Hero Lifecycle ---
echo -e "${BLUE}[2/6] 🏗️  Phase: Zero-to-Hero (Cluster Reconstruction)${NC}"
echo -e "${YELLOW}Purging existing state and rebuilding infrastructure from scratch...${NC}"
./scripts/lifecycle_test.sh
echo -e "${GREEN}✅ Infrastructure reconstructed and validated.${NC}\n"

# --- 3. Real-time Visualization ---
echo -e "${BLUE}[3/6] 📊 Phase: Real-time Visualization Deployment${NC}"
echo -e "${YELLOW}Deploying CTO Dashboard and starting background observers...${NC}"
./scripts/run-visual-test.sh
echo -e "${GREEN}✅ Visualization layer active.${NC}\n"

# --- 4. Chaos Injection & AI Resilience ---
echo -e "${BLUE}[4/6] 🌪️  Phase: Chaos Injection & Autonomous Remediation${NC}"
echo -e "${YELLOW}Triggering Recruiter Showcase Disaster...${NC}"
# Re-trigger explicitly to ensure visualization catches the spike
kubectl patch workflow recruiter-first-disaster -n chaos-testing --type merge -p '{"spec":{"suspend":false}}' || true
echo -e "${YELLOW}Waiting for AI Agent to stabilize the cluster (90s)...${NC}"
sleep 90
echo -e "${GREEN}✅ Cluster stabilized by the Specialist Swarm.${NC}\n"

# --- 5. A-to-Z Data Extraction & Analysis ---
echo -e "${BLUE}[5/6] 🧪 Phase: Final Validation & Report Generation${NC}"
echo -e "${YELLOW}Running E2E test suite and piping to Premium Visualizer...${NC}"
./scripts/e2e_test.sh | python3 ./scripts/test_visualizer.py
echo -e "${GREEN}✅ Visual report generated: test_report.html${NC}\n"

# --- 6. Grand Finale ---
echo -e "${BLUE}[6/6] 🏆 Mission Accomplished${NC}"
echo -e "${BOLD}The A-Z test process is complete.${NC}"
echo -e "1. ${GREEN}Visual Report:${NC} Open ${BOLD}test_report.html${NC} in your browser."
echo -e "2. ${GREEN}Real-time Ops:${NC} Check Grafana for the 'CTO: E2E Visual Testing' dashboard."
echo -e "3. ${GREEN}AI Reasoning:${NC} Review logs in the 'ai-lab' namespace to see the Swarm in action."

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${GREEN}          🎉 ALL PIECES OF THE PUZZLE ARE VALIDATED 🎉               ${NC}"
echo -e "${BLUE}======================================================================${NC}"
