#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# security-scan.sh — Local DevSecOps Scan for AI4ALL-SRE
#
# Run this BEFORE pushing code. It replicates the CI security gates locally.
#
# Usage:
#   ./scripts/security-scan.sh              # Run all checks
#   ./scripts/security-scan.sh --quick      # Run fast checks only (no image scan)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

QUICK_MODE=false
[[ "${1:-}" == "--quick" ]] && QUICK_MODE=true

PASS=0
FAIL=0
WARN=0

results=()

run_check() {
  local name="$1"
  shift
  echo -e "\n${CYAN}━━━ ${BOLD}${name}${NC}${CYAN} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if "$@"; then
    echo -e "${GREEN}✅ ${name} — PASSED${NC}"
    results+=("✅|${name}|PASS")
    PASS=$((PASS + 1))
  else
    echo -e "${RED}❌ ${name} — FAILED${NC}"
    results+=("❌|${name}|FAIL")
    FAIL=$((FAIL + 1))
  fi
}

run_check_warn() {
  local name="$1"
  shift
  echo -e "\n${CYAN}━━━ ${BOLD}${name}${NC}${CYAN} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  if "$@"; then
    echo -e "${GREEN}✅ ${name} — PASSED${NC}"
    results+=("✅|${name}|PASS")
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}⚠️  ${name} — WARNING (non-blocking)${NC}"
    results+=("⚠️|${name}|WARN")
    WARN=$((WARN + 1))
  fi
}

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        🔒 AI4ALL-SRE — Local Security Scan                  ║"
echo "║        Tier-1 Enterprise Grade DevSecOps Validation         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

cd "${PROJECT_ROOT}"

# ── 1. Secret Scanning ───────────────────────────────────────────────────────
check_gitleaks() {
  if command -v gitleaks &>/dev/null; then
    gitleaks detect --source . --no-banner --exit-code 1
  else
    echo "gitleaks not installed. Install: brew install gitleaks / go install github.com/gitleaks/gitleaks/v8@latest"
    return 1
  fi
}
run_check "Gitleaks (Secret Scanning)" check_gitleaks

# ── 2. Python SAST ───────────────────────────────────────────────────────────
check_bandit() {
  if command -v bandit &>/dev/null; then
    bandit -r components/ scripts/ tests/ -ll -q
  else
    pip install -q bandit
    bandit -r components/ scripts/ tests/ -ll -q
  fi
}
run_check "Bandit (Python SAST)" check_bandit

# ── 3. Dependency CVE Scan ───────────────────────────────────────────────────
check_pip_audit() {
  if [ -f "requirements.txt" ]; then
    if command -v pip-audit &>/dev/null; then
      pip-audit -r requirements.txt --desc
    else
      pip install -q pip-audit
      pip-audit -r requirements.txt --desc
    fi
  else
    echo "No requirements.txt found — skipping"
    return 0
  fi
}
run_check "pip-audit (Dependency CVEs)" check_pip_audit

# ── 4. Trivy Filesystem Scan ────────────────────────────────────────────────
check_trivy() {
  if command -v trivy &>/dev/null; then
    trivy fs --severity CRITICAL,HIGH --exit-code 1 .
  else
    echo "trivy not installed. Install: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
    return 1
  fi
}
run_check_warn "Trivy (IaC + Config Scan)" check_trivy

# ── 5. Dockerfile Lint ───────────────────────────────────────────────────────
check_hadolint() {
  local has_errors=0
  if command -v hadolint &>/dev/null; then
    for df in components/ai-agent/Dockerfile.agent components/loadgen/Dockerfile.loadgen docs/Dockerfile.docs-portal; do
      if [ -f "${df}" ]; then
        echo "  Scanning ${df}..."
        hadolint --ignore DL3008 --ignore DL3013 "${df}" || has_errors=1
      fi
    done
  elif command -v docker &>/dev/null; then
    for df in components/ai-agent/Dockerfile.agent components/loadgen/Dockerfile.loadgen docs/Dockerfile.docs-portal; do
      if [ -f "${df}" ]; then
        echo "  Scanning ${df}..."
        docker run --rm -i hadolint/hadolint < "${df}" || has_errors=1
      fi
    done
  else
    echo "hadolint not installed. Install: brew install hadolint"
    return 1
  fi
  return ${has_errors}
}
run_check_warn "Hadolint (Dockerfile Lint)" check_hadolint

# ── 6. ShellCheck ────────────────────────────────────────────────────────────
check_shellcheck() {
  if command -v shellcheck &>/dev/null; then
    local has_errors=0
    find scripts/ -name '*.sh' -exec shellcheck --severity=warning {} + || has_errors=1
    shellcheck --severity=warning setup.sh destroy.sh e2e_test.sh lifecycle_test.sh 2>/dev/null || has_errors=1
    return ${has_errors}
  else
    echo "shellcheck not installed. Install: sudo apt install shellcheck / brew install shellcheck"
    return 1
  fi
}
run_check_warn "ShellCheck (Bash Scripts)" check_shellcheck

# ── 7. Terraform Validation (if available) ───────────────────────────────────
check_terraform() {
  if command -v terraform &>/dev/null; then
    terraform fmt -check -recursive
    terraform init -backend=false -no-color 2>/dev/null
    terraform validate -no-color
  else
    echo "terraform not installed — skipping"
    return 0
  fi
}

if [ "${QUICK_MODE}" = false ]; then
  run_check_warn "Terraform (fmt + validate)" check_terraform
fi

# ── 8. YAML Lint ─────────────────────────────────────────────────────────────
check_yamllint() {
  if command -v yamllint &>/dev/null; then
    yamllint -d '{extends: relaxed, rules: {line-length: {max: 200}}}' .github/workflows/*.yml gitops/ || true
  else
    pip install -q yamllint
    yamllint -d '{extends: relaxed, rules: {line-length: {max: 200}}}' .github/workflows/*.yml gitops/ || true
  fi
}
run_check_warn "yamllint (YAML Validation)" check_yamllint

# ──────────────────────────────────────────────────────────────────────────────
# Summary Table
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    📊 Security Scan Summary                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "${NC}"

printf "  ${BOLD}%-4s %-40s %-10s${NC}\n" "" "Check" "Result"
echo "  ────────────────────────────────────────────────────────────"
for r in "${results[@]}"; do
  IFS='|' read -r icon name status <<< "${r}"
  printf "  %-4s %-40s %-10s\n" "${icon}" "${name}" "${status}"
done

echo ""
echo -e "  ${GREEN}Passed: ${PASS}${NC}  ${YELLOW}Warnings: ${WARN}${NC}  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [ "${FAIL}" -gt 0 ]; then
  echo -e "${RED}${BOLD}  ❌ SECURITY GATE FAILED — Fix blocking issues before pushing.${NC}"
  echo ""
  exit 1
else
  echo -e "${GREEN}${BOLD}  ✅ SECURITY GATE PASSED — Safe to push.${NC}"
  echo ""
  exit 0
fi
