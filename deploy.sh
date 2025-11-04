#!/bin/bash

# Deploy Redshift test cluster with CloudFormation

STACK_NAME="redshift-test-stack"
TEMPLATE_FILE="redshift-cluster.yaml"
REGION="us-east-2"

echo "Deploying Redshift test cluster..."
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo ""

# Deploy the stack
aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://$TEMPLATE_FILE \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION \
  --parameters \
    ParameterKey=ClusterIdentifier,ParameterValue=redshift-test-cluster \
    ParameterKey=MasterUsername,ParameterValue=awsuser \
    ParameterKey=MasterUserPassword,ParameterValue=TestPass123

if [ $? -eq 0 ]; then
  echo ""
  echo "✓ Stack creation initiated successfully!"
  echo ""
  echo "Monitor progress with:"
  echo "  aws cloudformation describe-stack-events --stack-name $STACK_NAME --region $REGION"
  echo ""
  echo "Wait for completion with:"
  echo "  aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION"
  echo ""
  echo "Get outputs with:"
  echo "  aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs'"
else
  echo "✗ Stack creation failed!"
  exit 1
fi
