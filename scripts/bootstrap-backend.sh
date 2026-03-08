#!/bin/bash
# 🚀 AI4ALL-SRE Backend Bootstrapper (10/10)
# Purpose: Provision S3 and DynamoDB for Terraform state before 'init'.

set -e

BUCKET_NAME="ai4all-sre-tfstate"
TABLE_NAME="ai4all-sre-tf-lock"
REGION=${AWS_REGION:-"us-east-1"}

echo "----------------------------------------------------"
echo "🛠️  Initializing Fortune 500 IaC Backend Assets..."
echo "----------------------------------------------------"

# 1. Create S3 Bucket
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ S3 Bucket '$BUCKET_NAME' already exists."
else
    echo "🏗️  Creating S3 Bucket '$BUCKET_NAME'..."
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" || \
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
fi

# 2. Enable Versioning (CRITICAL for State Recovery)
echo "🔒 Enabling S3 Versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# 3. Create DynamoDB Table for Locking
if aws dynamodb describe-table --table-name "$TABLE_NAME" 2>/dev/null; then
    echo "✅ DynamoDB Table '$TABLE_NAME' already exists."
else
    echo "🏗️  Creating DynamoDB Table '$TABLE_NAME' for atomic locking..."
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION"
fi

echo "----------------------------------------------------"
echo "✅ Backend Infrastructure Ready."
echo "👉 Next Step: terraform init"
echo "----------------------------------------------------"
