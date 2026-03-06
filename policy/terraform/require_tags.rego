# ──────────────────────────────────────────────────────────────────────────────
# OPA/Conftest Policy: Require Tags
# Ensures all Terraform resources include mandatory tags for governance,
# cost allocation, and compliance.
# ──────────────────────────────────────────────────────────────────────────────
package terraform.require_tags

import rego.v1

required_tags := {"team", "environment", "cost-center", "managed-by"}

# Deny resources that support tags but are missing required ones
deny contains msg if {
	some resource in input.resource_changes
	resource.change.after.tags != null
	some tag in required_tags
	not resource.change.after.tags[tag]
	msg := sprintf("Resource '%s' is missing required tag '%s'", [resource.address, tag])
}
