# AI4ALL-SRE Project Orchestration
# Standardized entry point for SRE automation and platform lifecycle.

.PHONY: help setup cleanup destroy test-lifecycle test-e2e security-scan

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initialize the hardware and cluster plane
	@./scripts/setup.sh

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
