# AI4ALL-SRE Project Orchestration
# Standardized entry point for SRE automation and platform lifecycle.

.PHONY: help setup cleanup destroy test-lifecycle test-e2e security-scan

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Industrial 10/10 Setup (Layered Infrastructure + Platform)
	@echo "🚀 Starting Layered Setup..."
	@$(MAKE) setup-infra
	@$(MAKE) setup-platform

setup-infra: ## Stage 1: Provision Core Infrastructure (Namespaces & CRDs)
	@echo "🏗️  Stage 1: Provisioning Core Infrastructure..."
	@./scripts/setup.sh --stage-1

setup-platform: ## Stage 2: Provision Platform Services (ArgoCD, Linkerd, AI)
	@echo "🧠 Stage 2: Provisioning Platform Services..."
	@./scripts/setup.sh --stage-2

# 🎓 Enterprise Portfolio Controls
enterprise-on: ## Enable 10/10 Enterprise Mode (Remote State/S3/DynamoDB)
	@mv .backend.tf.enterprise backend.tf 2>/dev/null || echo "Enterprise mode already active."
	@echo "🚀 10/10 Enterprise Mode: ENABLED. Run 'make setup' to bootstrap."

enterprise-off: ## Revert to Local Lab Mode (Frictionless Execution)
	@mv backend.tf .backend.tf.enterprise 2>/dev/null || echo "Local mode already active."
	@echo "🛡️  Local Lab Mode: ENABLED. Run 'make setup' for zero-config startup."

cleanup: ## Clean up temporary files and logs
	@./scripts/cleanup.sh

destroy: ## Tear down the cluster and infrastructure
	@./scripts/destroy.sh

test-lifecycle: ## Run full zero-to-hero lifecycle test
	@./scripts/lifecycle_test.sh

test-e2e: ## Run comprehensive end-to-end test suite
	@./scripts/e2e_test.sh

security-scan: ## Run local security gates
	@./scripts/security-scan.sh
