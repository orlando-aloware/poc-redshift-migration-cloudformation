# CloudFormation → Terraform Workflow

## Complete Deployment and Import Workflow

### Scenario: Deploy with CloudFormation, then manage with Terraform

#### Step 1: Deploy with CloudFormation
```bash
./deploy.sh
# Or manually:
aws cloudformation create-stack \
  --stack-name redshift-test-stack \
  --template-body file://redshift-cluster.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-2

# Wait for completion
./manage.sh status
```

#### Step 2: Import to Terraform (Automated)
```bash
./import-from-cloudformation.sh
```

This script will:
- ✅ Check if CloudFormation stack exists
- ✅ Get IAM role name automatically
- ✅ Update `main.tf` with correct role name
- ✅ Import IAM role
- ✅ Import IAM policy attachment
- ✅ Import Redshift cluster
- ✅ Verify with `terraform plan`

#### Step 3: Manage with Terraform
```bash
# View current state
terraform show
terraform output

# Make changes
# Edit main.tf, then:
terraform plan
terraform apply

# Destroy cluster
terraform destroy
```

---

## Full Lifecycle Example

### Cycle 1: CloudFormation → Terraform
```bash
# 1. Deploy with CloudFormation
./deploy.sh
./manage.sh status  # Wait until CREATE_COMPLETE

# 2. Import to Terraform
./import-from-cloudformation.sh

# 3. Verify
terraform plan  # Should show no changes

# 4. Destroy via Terraform
terraform destroy
```

### Cycle 2: Deploy CloudFormation Again
```bash
# 1. Deploy with CloudFormation again
./deploy.sh
./manage.sh status

# 2. Import to Terraform again (automated!)
./import-from-cloudformation.sh

# 3. Manage with Terraform
terraform plan
terraform apply
```

---

## Why Use This Workflow?

### Use CloudFormation when:
- Quick testing/experimentation
- Using AWS Console or CLI
- Need CloudFormation-specific features
- Part of larger CloudFormation stack

### Use Terraform when:
- Managing multiple cloud providers
- Complex infrastructure as code
- Version control and collaboration
- Advanced state management

### The Import Script Handles:
- ✅ Automatic IAM role name detection
- ✅ Updates Terraform config automatically
- ✅ Validates CloudFormation stack status
- ✅ Validates cluster existence
- ✅ Safe re-import (removes old state first)
- ✅ Verification with terraform plan

---

## Manual Import (Alternative)

If you prefer to import manually:

```bash
# 1. Get IAM role name
IAM_ROLE=$(aws cloudformation describe-stack-resources \
  --stack-name redshift-test-stack \
  --region us-east-2 \
  --query 'StackResources[?ResourceType==`AWS::IAM::Role`].PhysicalResourceId' \
  --output text)

# 2. Update main.tf with the role name

# 3. Import resources
terraform import aws_iam_role.redshift_role "$IAM_ROLE"
terraform import aws_iam_role_policy_attachment.redshift_s3 \
  "$IAM_ROLE/arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
terraform import aws_redshift_cluster.main redshift-test-cluster

# 4. Verify
terraform plan
```

---

## Script Reference

### CloudFormation Scripts
- `deploy.sh` - Deploy CloudFormation stack
- `manage.sh` - Manage CloudFormation stack (status, outputs, delete, etc.)

### Terraform Scripts
- `import-from-cloudformation.sh` - **Automated import from CloudFormation**

### CloudFormation Template
- `redshift-cluster.yaml` - Redshift cluster definition

### Terraform Configuration
- `main.tf` - Terraform infrastructure definition

---

## Notes

- Import is **idempotent** - safe to run multiple times
- The script will ask before overwriting existing Terraform state
- IAM role name changes each time CloudFormation stack is created
- The import script automatically detects and updates the role name
- After import, CloudFormation stack can be deleted (resources stay)

---

## Troubleshooting

### "Resources already in state"
Run the import script again - it will offer to clear and re-import

### "Stack not found"
Deploy the CloudFormation stack first: `./deploy.sh`

### "Cluster not available"
Wait for cluster to be ready: `./manage.sh status`

### Import fails
Check that:
- CloudFormation stack is CREATE_COMPLETE
- Cluster status is "available"
- AWS credentials are configured
- Region is correct (us-east-2)
