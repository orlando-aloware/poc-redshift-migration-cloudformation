#!/bin/bash

# Redshift Test Cluster Management Script

STACK_NAME="redshift-test-stack"
CLUSTER_ID="redshift-test-cluster"
REGION="us-east-2"

function show_usage() {
  cat << EOF
Usage: ./manage.sh [command]

Commands:
  deploy              Deploy the Redshift cluster
  status              Check cluster status
  outputs             Show stack outputs (endpoint, connection string)
  allow-my-ip         Add your current IP to security group
  connect             Show connection command
  delete              Delete the stack and cluster
  logs                Show CloudFormation stack events
  help                Show this help message

EOF
}

function deploy_cluster() {
  echo "🚀 Deploying Redshift cluster..."
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://redshift-cluster.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION
  
  if [ $? -eq 0 ]; then
    echo "✓ Stack creation initiated!"
    echo "Run './manage.sh status' to check progress"
  fi
}

function check_status() {
  echo "📊 Checking cluster status..."
  aws redshift describe-clusters \
    --cluster-identifier $CLUSTER_ID \
    --region $REGION \
    --query 'Clusters[0].[ClusterIdentifier,ClusterStatus,NodeType,NumberOfNodes]' \
    --output table 2>/dev/null || echo "Cluster not found or not ready yet"
  
  echo ""
  echo "Stack status:"
  aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].[StackName,StackStatus]' \
    --output table 2>/dev/null || echo "Stack not found"
}

function show_outputs() {
  echo "📋 Stack Outputs:"
  aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs' \
    --output table
}

function allow_my_ip() {
  echo "🔓 Adding your IP to security group..."
  MY_IP=$(curl -s https://checkip.amazonaws.com)
  echo "Your IP: $MY_IP"
  
  SG_ID=$(aws redshift describe-clusters \
    --cluster-identifier $CLUSTER_ID \
    --region $REGION \
    --query 'Clusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text)
  
  if [ -z "$SG_ID" ]; then
    echo "✗ Could not find security group"
    exit 1
  fi
  
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 5439 \
    --cidr ${MY_IP}/32 \
    --region $REGION
  
  echo "✓ Your IP ($MY_IP) has been added to security group $SG_ID"
}

function show_connect() {
  ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ClusterEndpoint`].OutputValue' \
    --output text)
  
  echo "🔌 Connect to Redshift:"
  echo ""
  echo "Using psql:"
  echo "  psql -h $ENDPOINT -p 5439 -U awsuser -d dev"
  echo ""
  echo "JDBC URL:"
  echo "  jdbc:redshift://$ENDPOINT:5439/dev"
}

function delete_cluster() {
  read -p "⚠️  Are you sure you want to delete the cluster? (yes/no): " confirm
  if [ "$confirm" = "yes" ]; then
    echo "🗑️  Deleting stack..."
    aws cloudformation delete-stack \
      --stack-name $STACK_NAME \
      --region $REGION
    echo "✓ Deletion initiated"
  else
    echo "Cancelled"
  fi
}

function show_logs() {
  echo "📜 Recent stack events:"
  aws cloudformation describe-stack-events \
    --stack-name $STACK_NAME \
    --region $REGION \
    --max-items 10 \
    --query 'StackEvents[].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
    --output table
}

# Main script
case "$1" in
  deploy)
    deploy_cluster
    ;;
  status)
    check_status
    ;;
  outputs)
    show_outputs
    ;;
  allow-my-ip)
    allow_my_ip
    ;;
  connect)
    show_connect
    ;;
  delete)
    delete_cluster
    ;;
  logs)
    show_logs
    ;;
  help|*)
    show_usage
    ;;
esac
