# ──────────────────────────────────────────────────────────────────────────────
# OPA/Conftest Policy: Require Resource Limits (Kubernetes)
# Ensures all containers define CPU and memory limits.
# ──────────────────────────────────────────────────────────────────────────────
package kubernetes.require_resource_limits

import rego.v1

deny contains msg if {
	input.kind == "Pod"
	some container in input.spec.containers
	not container.resources.limits.cpu
	msg := sprintf("Container '%s' in Pod '%s' must define CPU limits", [container.name, input.metadata.name])
}

deny contains msg if {
	input.kind == "Pod"
	some container in input.spec.containers
	not container.resources.limits.memory
	msg := sprintf("Container '%s' in Pod '%s' must define memory limits", [container.name, input.metadata.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.resources.limits
	msg := sprintf("Container '%s' in Deployment '%s' must define resource limits", [container.name, input.metadata.name])
}
