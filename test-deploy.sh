#!/bin/bash

# Test script to validate deploy.sh configuration

echo "🧪 Testing deploy.sh Configuration"
echo "===================================="
echo ""

# Test 1: Check if deploy.sh exists and is executable
echo "1️⃣  Checking deploy.sh..."
if [ -x "./deploy.sh" ]; then
    echo "✅ deploy.sh exists and is executable"
else
    echo "❌ deploy.sh is not executable or doesn't exist"
    exit 1
fi
echo ""

# Test 2: Check if template file exists
echo "2️⃣  Checking CloudFormation template..."
if [ -f "redshift-cluster.yaml" ]; then
    echo "✅ redshift-cluster.yaml exists"
else
    echo "❌ redshift-cluster.yaml not found"
    exit 1
fi
echo ""

# Test 3: Validate CloudFormation template
echo "3️⃣  Validating CloudFormation template syntax..."
if aws cloudformation validate-template \
    --template-body file://redshift-cluster.yaml \
    --region us-east-2 &>/dev/null; then
    echo "✅ Template is valid"
else
    echo "❌ Template validation failed"
    exit 1
fi
echo ""

# Test 4: Check AWS credentials
echo "4️⃣  Checking AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    echo "✅ AWS credentials configured (Account: $ACCOUNT)"
else
    echo "❌ AWS credentials not configured"
    exit 1
fi
echo ""

# Test 5: Check if region is accessible
echo "5️⃣  Checking region accessibility..."
if aws cloudformation list-stacks --region us-east-2 &>/dev/null; then
    echo "✅ Region us-east-2 is accessible"
else
    echo "❌ Cannot access us-east-2 region"
    exit 1
fi
echo ""

# Test 6: Check if stack already exists
echo "6️⃣  Checking for existing stack..."
EXISTING_STACK=$(aws cloudformation describe-stacks \
    --stack-name redshift-test-stack \
    --region us-east-2 \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "NONE")

if [ "$EXISTING_STACK" != "NONE" ]; then
    echo "⚠️  Stack already exists with status: $EXISTING_STACK"
    echo ""
    echo "   To deploy a new stack, you must first delete the existing one:"
    echo "   aws cloudformation delete-stack --stack-name redshift-test-stack --region us-east-2"
    echo "   Or use: ./manage.sh delete"
else
    echo "✅ No existing stack found - ready to deploy"
fi
echo ""

# Test 7: Extract and display script configuration
echo "7️⃣  Deploy script configuration:"
echo "   Stack Name: redshift-test-stack"
echo "   Region: us-east-2"
echo "   Template: redshift-cluster.yaml"
echo "   Cluster ID: redshift-test-cluster"
echo "   Username: awsuser"
echo "   Password: TestPass123"
echo ""

# Summary
echo "===================================="
echo "📋 Summary"
echo "===================================="
echo ""
if [ "$EXISTING_STACK" = "NONE" ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "The deploy.sh script is ready to use:"
    echo "  ./deploy.sh"
    echo ""
    echo "After deployment, you can:"
    echo "  - Check status: ./manage.sh status"
    echo "  - Import to Terraform: ./import-from-cloudformation.sh"
else
    echo "⚠️  Configuration is valid, but stack already exists"
    echo ""
    echo "Options:"
    echo "  1. Delete existing stack first:"
    echo "     ./manage.sh delete"
    echo ""
    echo "  2. Keep existing stack and import to Terraform:"
    echo "     ./import-from-cloudformation.sh"
fi
echo ""
