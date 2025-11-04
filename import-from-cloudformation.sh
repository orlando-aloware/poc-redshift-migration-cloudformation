#!/bin/bash

# Automated Terraform Import Script for CloudFormation-created Redshift Cluster
# This script imports CloudFormation-created resources into Terraform state

set -e

STACK_NAME="redshift-test-stack"
CLUSTER_ID="redshift-test-cluster"
REGION="us-east-2"

echo "🔄 Starting Terraform Import Process..."
echo "=================================="
echo "Stack: $STACK_NAME"
echo "Cluster: $CLUSTER_ID"
echo "Region: $REGION"
echo ""

# Check if CloudFormation stack exists
echo "📋 Checking CloudFormation stack..."
if ! aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text &>/dev/null; then
    echo "❌ CloudFormation stack '$STACK_NAME' not found!"
    echo "Please deploy the stack first with: ./deploy.sh"
    exit 1
fi

STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text)

if [ "$STACK_STATUS" != "CREATE_COMPLETE" ] && [ "$STACK_STATUS" != "UPDATE_COMPLETE" ]; then
    echo "❌ Stack is in state: $STACK_STATUS"
    echo "Stack must be in CREATE_COMPLETE or UPDATE_COMPLETE state"
    exit 1
fi

echo "✓ Stack found and ready"
echo ""

# Get IAM Role name from CloudFormation
echo "🔍 Getting IAM role name from CloudFormation..."
IAM_ROLE_NAME=$(aws cloudformation describe-stack-resources \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'StackResources[?ResourceType==`AWS::IAM::Role`].PhysicalResourceId' \
    --output text)

if [ -z "$IAM_ROLE_NAME" ]; then
    echo "❌ Could not find IAM role in stack"
    exit 1
fi

echo "✓ IAM Role: $IAM_ROLE_NAME"
echo ""

# Verify cluster exists
echo "🔍 Verifying Redshift cluster..."
if ! aws redshift describe-clusters \
    --cluster-identifier $CLUSTER_ID \
    --region $REGION &>/dev/null; then
    echo "❌ Redshift cluster '$CLUSTER_ID' not found!"
    exit 1
fi

CLUSTER_STATUS=$(aws redshift describe-clusters \
    --cluster-identifier $CLUSTER_ID \
    --region $REGION \
    --query 'Clusters[0].ClusterStatus' \
    --output text)

echo "✓ Cluster found (status: $CLUSTER_STATUS)"
echo ""

# Update main.tf with the correct IAM role name
echo "📝 Updating main.tf with IAM role name..."
sed -i.bak "s/name = \"redshift-test-stack-RedshiftIAMRole-[^\"]*\"/name = \"$IAM_ROLE_NAME\"/" main.tf
rm -f main.tf.bak
echo "✓ Updated main.tf"
echo ""

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
    echo ""
fi

# Check if resources are already imported
echo "🔍 Checking current Terraform state..."
if terraform state list | grep -q "aws_iam_role.redshift_role"; then
    echo "⚠️  Resources already in Terraform state!"
    echo ""
    read -p "Do you want to remove existing state and re-import? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo "🗑️  Removing existing resources from state..."
        terraform state rm aws_redshift_cluster.main 2>/dev/null || true
        terraform state rm aws_iam_role_policy_attachment.redshift_s3 2>/dev/null || true
        terraform state rm aws_iam_role.redshift_role 2>/dev/null || true
        echo "✓ State cleared"
    else
        echo "❌ Import cancelled"
        exit 1
    fi
fi

echo ""
echo "🔄 Starting import process..."
echo ""

# Import IAM Role
echo "1️⃣  Importing IAM Role..."
if terraform import aws_iam_role.redshift_role "$IAM_ROLE_NAME"; then
    echo "✓ IAM Role imported successfully"
else
    echo "❌ Failed to import IAM Role"
    exit 1
fi
echo ""

# Import IAM Policy Attachment
echo "2️⃣  Importing IAM Policy Attachment..."
if terraform import aws_iam_role_policy_attachment.redshift_s3 \
    "$IAM_ROLE_NAME/arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"; then
    echo "✓ IAM Policy Attachment imported successfully"
else
    echo "❌ Failed to import IAM Policy Attachment"
    exit 1
fi
echo ""

# Import Redshift Cluster
echo "3️⃣  Importing Redshift Cluster..."
if terraform import aws_redshift_cluster.main "$CLUSTER_ID"; then
    echo "✓ Redshift Cluster imported successfully"
else
    echo "❌ Failed to import Redshift Cluster"
    exit 1
fi
echo ""

# Verify import
echo "✅ Running terraform plan to verify import..."
echo ""
terraform plan
echo ""

echo "=================================="
echo "✅ Import Complete!"
echo ""
echo "📊 Current Terraform state:"
terraform state list
echo ""
echo "📋 Next steps:"
echo "  - Run 'terraform plan' to verify no changes needed"
echo "  - Run 'terraform output' to see cluster details"
echo "  - Manage cluster with 'terraform apply' and 'terraform destroy'"
echo ""
echo "💡 Tip: You can now optionally delete the CloudFormation stack"
echo "   (resources won't be deleted as they're managed by Terraform)"
