# SOP: Remote State Migration (Tier-1 Enterprise Standards)

This Standard Operating Procedure (SOP) outlines the "Zero-Downtime" migration from local Terraform state to a remote backend with atomic locking.

## 📋 Prerequisites
- AWS CLI installed and configured (`aws configure`).
- IAM permissions for S3 and DynamoDB creation.
- An existing local `terraform.tfstate` file (if you have already run `make setup`).

---

## 🔐 Step 1: Install and Configure AWS CLI

### 1.1 Install AWS CLI v2

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**macOS:**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**Verify installation:**
```bash
aws --version
# Expected: aws-cli/2.x.x Python/3.x.x ...
```

### 1.2 Configure AWS Credentials

**Option A: Interactive Configuration (Recommended)**
```bash
aws configure
```
You'll be prompted for:
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-1
Default output format [None]: json
```

**Option B: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

**Option C: AWS SSO (for enterprise accounts)**
```bash
aws configure sso
# Follow the browser-based authentication flow
```

### 1.3 Verify Credentials with Test Script

Run the built-in test script to verify everything is working:

```bash
./scripts/test-aws-credentials.sh
```

**Expected Output:**
```
╔══════════════════════════════════════════════════╗
║        AWS Credentials Test                      ║
╚══════════════════════════════════════════════════╝

1. AWS CLI installed? ✅ YES (aws-cli/2.15.0 ...)
2. Credentials configured? ✅ YES
3. Credentials valid? ✅ YES
   Account:  123456789012
   User/Role: arn:aws:iam::123456789012:user/admin
   User ID:  AIDAXXXXXXXXXXXXXXXXX

4. S3 Buckets (aws s3 ls):
────────────────────────────────────────────────────
✅ S3 access working

5. DynamoDB Tables (aws dynamodb list-tables --region us-east-1):
────────────────────────────────────────────────────
{
    "TableNames": []
}
✅ DynamoDB access working
```

---

## 🚀 Step 2: Enable Enterprise Mode

### 2.1 Switch to Enterprise Backend

```bash
make enterprise-on
```

This moves `.backend.tf.enterprise` → `backend.tf`, activating the S3 + DynamoDB backend configuration.

**What happens:**
```bash
# Before (Local Lab Mode)
backend.tf does not exist
.terraform/           # Local state
terraform.tfstate     # Local state file

# After (Enterprise Mode)
backend.tf            # S3 + DynamoDB config
.terraform/           # Will connect to remote state
```

### 2.2 Review Backend Configuration

The `backend.tf` file contains:
```hcl
terraform {
  backend "s3" {
    bucket         = "ai4all-sre-tfstate"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ai4all-sre-tf-lock"
    encrypt        = true
  }
}
```

---

## ☁️ Step 3: Bootstrap Cloud Assets

### 3.1 Run Bootstrap Script

```bash
./scripts/bootstrap-backend.sh
```

**What it creates:**

| Resource | Name | Purpose |
|----------|------|---------|
| S3 Bucket | `ai4all-sre-tfstate` | Stores Terraform state |
| S3 Versioning | Enabled | Allows state recovery |
| DynamoDB Table | `ai4all-sre-tf-lock` | Prevents concurrent modifications |

**Expected Output:**
```
────────────────────────────────────────────────────
🛠️  Initializing Tier-1 Enterprise IaC Backend Assets...
────────────────────────────────────────────────────
🏗️  Creating S3 Bucket 'ai4all-sre-tfstate'...
🔒 Enabling S3 Versioning...
🏗️  Creating DynamoDB Table 'ai4all-sre-tf-lock' for atomic locking...
────────────────────────────────────────────────────
✅ Backend Infrastructure Ready.
👉 Next Step: terraform init
────────────────────────────────────────────────────
```

### 3.2 Verify Resources in AWS Console

**S3 Console:** https://s3.console.aws.amazon.com/s3/buckets/ai4all-sre-tfstate

**DynamoDB Console:** https://console.aws.amazon.com/dynamodb/home#tables:selected=ai4all-sre-tf-lock

---

## 🔄 Step 4: Initialize Terraform with Remote Backend

### 4.1 Run Terraform Init

```bash
terraform init
```

**If migrating from local state:**
```
Do you want to copy existing state to the new backend?
  Pre-existing state was found in the prior backend and no "sources" were set.
  Enter "yes" to copy the state to the new backend.
  
  Enter a value: yes
```

Type **`yes`** to migrate your local state to S3.

### 4.2 Verify Remote State

```bash
# List all resources in state
terraform state list

# Show current workspace
terraform workspace show

# Check state location
cat .terraform/environment
```

---

## ✅ Step 5: Full Verification

### 5.1 Run Complete Setup

```bash
make setup
```

This will:
1. Detect enterprise mode (backend.tf exists)
2. Prompt to bootstrap S3/DynamoDB (if not already done)
3. Initialize Terraform with remote backend
4. Deploy the full platform

### 5.2 Test S3 Access

```bash
# List all objects in the state bucket
aws s3 ls s3://ai4all-sre-tfstate/global/s3/

# Download state (for backup)
aws s3 cp s3://ai4all-sre-tfstate/global/s3/terraform.tfstate ./backup.tfstate
```

### 5.3 Test DynamoDB Locking

```bash
# List lock table items
aws dynamodb scan --table-name ai4all-sre-tf-lock

# During terraform apply, verify lock is acquired
aws dynamodb get-item \
  --table-name ai4all-sre-tf-lock \
  --key '{"LockID": {"S": "ai4all-sre-tfstate/global/s3/terraform.tfstate"}}'
```

---

## 🔒 Understanding State Locking

```mermaid
sequenceDiagram
    participant Dev1 as Developer 1
    participant Dev2 as Developer 2
    participant DDB as DynamoDB
    participant S3 as S3 Bucket

    Dev1->>DDB: Acquire Lock (PutItem)
    DDB-->>Dev1: Lock Acquired ✅
    Dev1->>S3: Upload State
    S3-->>Dev1: Upload Complete
    Dev1->>DDB: Release Lock (DeleteItem)

    Dev2->>DDB: Acquire Lock (PutItem)
    Note over Dev2,DDB: Waits if Dev1 holds lock
    DDB-->>Dev2: Lock Acquired ✅
    Dev2->>S3: Download Latest State
    Dev2->>S3: Upload New State
    Dev2->>DDB: Release Lock (DeleteItem)
```

---

## 🛡️ Security Best Practices

| Practice | Implementation |
|----------|----------------|
| **Encryption at Rest** | S3 SSE-S3 or SSE-KMS encryption |
| **Versioning** | S3 versioning for state recovery |
| **IAM Roles** | Use instance profiles, not access keys |
| **Least Privilege** | Scoped IAM policies for S3 + DynamoDB |
| **Audit Logging** | CloudTrail logs all state access |

**Recommended IAM Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::ai4all-sre-tfstate",
        "arn:aws:s3:::ai4all-sre-tfstate/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/ai4all-sre-tf-lock"
    }
  ]
}
```

---

## 🔙 Reverting to Local Lab Mode

```bash
make enterprise-off
```

This moves `backend.tf` → `.backend.tf.enterprise`, reverting to local state storage.

---

## 📊 Troubleshooting

| Issue | Solution |
|-------|----------|
| `Access Denied` | Check IAM permissions for S3 + DynamoDB |
| `Bucket already exists` | Use unique bucket name or different AWS account |
| `State locked` | Wait or run `terraform force-unlock <LOCK_ID>` |
| `Credentials not found` | Run `aws configure` or set env variables |
| `Region mismatch` | Ensure `AWS_REGION` matches bucket region |

### Force Unlock (Emergency Only)

```bash
# Get the lock ID from error message or DynamoDB
terraform force-unlock <LOCK_ID>
```

---

> [!IMPORTANT]
> From this point forward, every `terraform plan` or `apply` will automatically acquire a lock in DynamoDB, preventing "Split-Brain" infrastructure changes.
