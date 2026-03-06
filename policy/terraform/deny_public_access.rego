# ──────────────────────────────────────────────────────────────────────────────
# OPA/Conftest Policy: Deny Public Access
# Validates Terraform plans to ensure no resources expose public endpoints
# without explicit approval.
# ──────────────────────────────────────────────────────────────────────────────
package terraform.deny_public_access

import rego.v1

# Deny security groups with unrestricted ingress (0.0.0.0/0)
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_security_group_rule"
	resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
	resource.change.after.type == "ingress"
	msg := sprintf("Security group rule '%s' allows unrestricted ingress (0.0.0.0/0)", [resource.address])
}

# Deny S3 buckets without Block Public Access
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_s3_bucket_public_access_block"
	resource.change.after.block_public_acls != true
	msg := sprintf("S3 bucket '%s' does not block public ACLs", [resource.address])
}

# Deny Load Balancers marked as external without explicit tag
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_lb"
	resource.change.after.internal == false
	not resource.change.after.tags["public-approved"]
	msg := sprintf("Load balancer '%s' is public but missing 'public-approved' tag", [resource.address])
}
