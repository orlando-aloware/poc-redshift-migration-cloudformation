# Redshift Test Cluster - CloudFormation

## Overview
This CloudFormation template creates a minimal-cost Redshift cluster for testing purposes.

### Cost Optimization
- **Single-node cluster** using `dc2.large` (cheapest Redshift option)
- **No encryption** (reduces overhead)
- **No automated snapshots** (retention period = 0)
- **Publicly accessible** (no VPC/NAT costs)
- **Basic IAM role** (S3 read-only access)

**Estimated cost**: ~$0.25/hour or ~$180/month (on-demand pricing)

## Quick Start

### 1. Deploy the Stack

```bash
# Make the deploy script executable
chmod +x deploy.sh

# Deploy the stack
./deploy.sh
```

Or deploy manually:

```bash
aws cloudformation create-stack \
  --stack-name redshift-test-stack \
  --template-body file://redshift-cluster.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-2 \
  --parameters \
    ParameterKey=ClusterIdentifier,ParameterValue=redshift-test-cluster \
    ParameterKey=MasterUsername,ParameterValue=awsuser \
    ParameterKey=MasterUserPassword,ParameterValue=TestPass123
```

### 2. Wait for Stack Creation

```bash
aws cloudformation wait stack-create-complete \
  --stack-name redshift-test-stack \
  --region us-east-2
```

### 3. Get Connection Details

```bash
aws cloudformation describe-stacks \
  --stack-name redshift-test-stack \
  --region us-east-2 \
  --query 'Stacks[0].Outputs'
```

## Connect to Redshift

### Using psql

```bash
psql -h <ClusterEndpoint> -p 5439 -U awsuser -d dev
```

### JDBC Connection String
```
jdbc:redshift://<ClusterEndpoint>:5439/dev
```

### Python Example

```python
import psycopg2

conn = psycopg2.connect(
    host='<ClusterEndpoint>',
    port=5439,
    database='dev',
    user='awsuser',
    password='TestPass123'
)

cur = conn.cursor()
cur.execute("SELECT version();")
print(cur.fetchone())
conn.close()
```

## Security Configuration

### Allow Access from Your IP

Since the cluster is publicly accessible, you need to update the security group:

```bash
# Get your public IP
MY_IP=$(curl -s https://checkip.amazonaws.com)

# Get the security group ID
SG_ID=$(aws redshift describe-clusters \
  --cluster-identifier redshift-test-cluster \
  --region us-east-2 \
  --query 'Clusters[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

# Allow your IP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 5439 \
  --cidr ${MY_IP}/32 \
  --region us-east-2
```

## Delete the Stack

**Important**: To avoid ongoing costs, delete the stack when done:

```bash
aws cloudformation delete-stack \
  --stack-name redshift-test-stack \
  --region us-east-2
```

## Customization

Edit `redshift-cluster.yaml` to modify:
- Cluster identifier
- Master username/password
- Database name
- AWS region (in deploy.sh)

## Stack Resources

The template creates:
- 1 Redshift cluster (single-node dc2.large)
- 1 IAM role for S3 access
- Associated security group (in default VPC)

## Troubleshooting

### View Stack Events
```bash
aws cloudformation describe-stack-events \
  --stack-name redshift-test-stack \
  --region us-east-2 \
  --max-items 10
```

### Check Cluster Status
```bash
aws redshift describe-clusters \
  --cluster-identifier redshift-test-cluster \
  --region us-east-2
```

### Connection Issues
- Ensure security group allows your IP on port 5439
- Verify the cluster status is "available"
- Check the endpoint address is correct
