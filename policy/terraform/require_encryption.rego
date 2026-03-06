# ──────────────────────────────────────────────────────────────────────────────
# OPA/Conftest Policy: Require Encryption
# Ensures all storage and database resources have encryption enabled.
# ──────────────────────────────────────────────────────────────────────────────
package terraform.require_encryption

import rego.v1

# Deny RDS instances without encryption at rest
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_db_instance"
	resource.change.after.storage_encrypted != true
	msg := sprintf("RDS instance '%s' must have encryption at rest enabled", [resource.address])
}

# Deny EBS volumes without encryption
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_ebs_volume"
	resource.change.after.encrypted != true
	msg := sprintf("EBS volume '%s' must be encrypted", [resource.address])
}

# Deny S3 buckets without server-side encryption configuration
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_s3_bucket"
	not has_sse_config(resource)
	msg := sprintf("S3 bucket '%s' must have server-side encryption configured", [resource.address])
}

has_sse_config(resource) if {
	resource.change.after.server_side_encryption_configuration
}
