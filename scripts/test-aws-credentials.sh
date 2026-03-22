#!/bin/bash
# 🔐 AWS Credentials Test Script
# Tests if AWS credentials are configured and working

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔══════════════════════════════════════════════════╗"
echo "║        AWS Credentials Test                      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# 1. Check if AWS CLI is installed
echo -n "1. AWS CLI installed? "
if command -v aws &> /dev/null; then
    echo -e "${GREEN}✅ YES${NC} ($(aws --version 2>&1 | cut -d' ' -f1,2,3))"
else
    echo -e "${RED}❌ NO${NC}"
    echo ""
    echo "Install AWS CLI:"
    echo "  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    echo "  unzip awscliv2.zip && sudo ./aws/install"
    exit 1
fi

# 2. Check if credentials are configured
echo -n "2. Credentials configured? "
if [ -f "$HOME/.aws/credentials" ] || [ -n "$AWS_ACCESS_KEY_ID" ] || [ -n "$AWS_PROFILE" ]; then
    echo -e "${GREEN}✅ YES${NC}"
else
    echo -e "${RED}❌ NO${NC}"
    echo ""
    echo "Configure credentials:"
    echo "  aws configure"
    echo "  OR set environment variables:"
    echo "    export AWS_ACCESS_KEY_ID='your-key'"
    echo "    export AWS_SECRET_ACCESS_KEY='your-secret'"
    exit 1
fi

# 3. Test credentials with STS
echo -n "3. Credentials valid? "
IDENTITY=$(aws sts get-caller-identity 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ YES${NC}"
    echo ""
    echo "   Account:  $(echo "$IDENTITY" | grep -oP '"Account":\s*"\K[^"]+')"
    echo "   User/Role: $(echo "$IDENTITY" | grep -oP '"Arn":\s*"\K[^"]+')"
    echo "   User ID:  $(echo "$IDENTITY" | grep -oP '"UserId":\s*"\K[^"]+')"
else
    echo -e "${RED}❌ NO${NC}"
    echo ""
    echo "Error: $IDENTITY"
    exit 1
fi

# 4. Test S3 access
echo ""
echo "4. S3 Buckets (aws s3 ls):"
echo "────────────────────────────────────────────────────"
if aws s3 ls 2>&1; then
    echo -e "${GREEN}✅ S3 access working${NC}"
else
    echo -e "${YELLOW}⚠️  S3 access failed (may need s3:ListAllMyBuckets permission)${NC}"
fi

# 5. Test DynamoDB access
echo ""
echo "5. DynamoDB Tables (aws dynamodb list-tables --region us-east-1):"
echo "────────────────────────────────────────────────────"
if aws dynamodb list-tables --region us-east-1 2>&1; then
    echo -e "${GREEN}✅ DynamoDB access working${NC}"
else
    echo -e "${YELLOW}⚠️  DynamoDB access failed (may need dynamodb:ListTables permission)${NC}"
fi

echo ""
echo "────────────────────────────────────────────────────"
echo -e "${GREEN}✅ AWS credentials are working!${NC}"
echo "────────────────────────────────────────────────────"
