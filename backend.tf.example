# Fix 8: Remote Terraform Backend
# Migrates from local state (single-machine, no locking) to S3-compatible storage.
# For local lab use, MinIO provides an S3-compatible backend.
#
# ACTIVATION INSTRUCTIONS:
# 1. Deploy MinIO in the cluster: kubectl apply -f scripts/minio-backend.yaml
# 2. Create the bucket: mc alias set local http://localhost:9000 admin password
#                       mc mb local/ai4all-sre-tfstate
# 3. Set environment variables:
#    export AWS_ACCESS_KEY_ID=admin
#    export AWS_SECRET_ACCESS_KEY=password
# 4. Run: terraform init -reconfigure
#
# For production: replace endpoint_url with your S3/GCS bucket and use IAM roles.

terraform {
  backend "s3" {
    bucket                      = "ai4all-sre-tfstate"
    key                         = "lab/terraform.tfstate"
    region                      = "us-east-1"      # Required field, value ignored by MinIO
    endpoint                    = "http://minio.minio.svc.cluster.local:9000"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
    use_path_style              = true

    # State locking via DynamoDB-compatible table (MinIO does not support this natively;
    # for production use AWS DynamoDB or Terraform Cloud).
    # dynamodb_table = "terraform-state-lock"
    encrypt = true
  }
}
