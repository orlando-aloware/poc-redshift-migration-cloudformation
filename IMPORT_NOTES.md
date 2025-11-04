# CloudFormation to Terraform Import

## What Was Done

Successfully imported the Redshift cluster from CloudFormation to Terraform management.

### Resources Imported

1. **IAM Role**: `redshift-test-stack-RedshiftIAMRole-c7rTSfk6F7yi`
2. **IAM Policy Attachment**: S3 ReadOnly access
3. **Redshift Cluster**: `redshift-test-cluster`

### Import Commands Used

```bash
# 1. Import IAM Role
terraform import aws_iam_role.redshift_role redshift-test-stack-RedshiftIAMRole-c7rTSfk6F7yi

# 2. Import IAM Policy Attachment
terraform import aws_iam_role_policy_attachment.redshift_s3 \
  "redshift-test-stack-RedshiftIAMRole-c7rTSfk6F7yi/arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"

# 3. Import Redshift Cluster
terraform import aws_redshift_cluster.main redshift-test-cluster
```

## Current State

- ✅ All resources are now managed by Terraform
- ✅ `terraform plan` shows no changes needed
- ✅ CloudFormation stack is still active (can be deleted if desired)

## Managing Resources

### View Current State
```bash
terraform show
terraform output
```

### Make Changes
Edit `main.tf` and run:
```bash
terraform plan
terraform apply
```

### Delete Cluster (via Terraform)
```bash
terraform destroy
```

## Next Steps

You can now:
1. Keep CloudFormation stack for reference OR delete it
2. Manage the cluster entirely through Terraform
3. Add more resources to the Terraform configuration

### To Delete CloudFormation Stack (Optional)

Since resources are now in Terraform, you can optionally delete the CloudFormation stack:

```bash
# This will NOT delete the cluster since it's now managed by Terraform
aws cloudformation delete-stack \
  --stack-name redshift-test-stack \
  --region us-east-2
```

**Note**: The CloudFormation delete will fail if it tries to delete resources. You may need to:
1. Remove resources from CloudFormation template
2. Update the stack with empty resources
3. Then delete the stack

Or simply leave the CloudFormation stack as documentation.

## Connection Details

```bash
# Get outputs
terraform output

# Connect via psql
psql -h $(terraform output -raw cluster_endpoint | cut -d: -f1) \
     -p 5439 -U awsuser -d dev
```

## Important Notes

- The master password is set to ignore changes in Terraform (`ignore_changes = [master_password]`)
- Don't commit sensitive values like passwords to git
- Consider using AWS Secrets Manager or environment variables for sensitive data
