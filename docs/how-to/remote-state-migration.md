# SOP: Remote State Migration (Fortune 500 Standards)

This Standard Operating Procedure (SOP) outlines the "Zero-Downtime" migration from local Terraform state to a remote backend with atomic locking.

## 📋 Prerequisites
- AWS CLI installed and configured (`aws configure`).
- IAM permissions for S3 and DynamoDB creation.
- An existing local `terraform.tfstate` file (if you have already run `make setup`).

## 🚀 Migration Steps

### 1. Bootstrap the Cloud Assets
Run the automated bootstrap script to provision the S3 bucket and DynamoDB table.
```bash
chmod +x scripts/bootstrap-backend.sh
./scripts/bootstrap-backend.sh
```
> [!NOTE]
> This script enables **S3 Versioning**, which is critical for state recovery if a corruption occurs.

### 2. Initialize the Remote Backend
Run the initialization command. Terraform will detect the `backend` block in `backend.tf`.
```bash
terraform init
```

### 3. Confirm State Transfer
When prompted with:
`Do you want to copy existing state to the new backend?`
Type **`yes`**.

Terraform will upload your local `terraform.tfstate` to the S3 bucket and verify the lock table.

### 4. Verification
Verify that the state is now managed remotely:
```bash
terraform state list
```
Check the AWS Console (S3) to see the `global/s3/terraform.tfstate` file.

### 5. Local Cleanup
Once migration is confirmed, you can safely remove the local state files:
```bash
rm terraform.tfstate terraform.tfstate.backup
```

---
> [!IMPORTANT]
> From this point forward, every `terraform plan` or `apply` will automatically acquire a lock in DynamoDB, preventing "Split-Brain" infrastructure changes.
