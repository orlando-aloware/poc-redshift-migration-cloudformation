provider "aws" {
  region = "us-east-2"
}

# Import the IAM role created by CloudFormation
resource "aws_iam_role" "redshift_role" {
  name = "redshift-test-stack-RedshiftIAMRole-VhvtypD3sjhl"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { 
        Service = "redshift.amazonaws.com" 
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_s3" {
  role       = aws_iam_role.redshift_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Import the Redshift cluster created by CloudFormation
resource "aws_redshift_cluster" "main" {
  cluster_identifier  = "redshift-test-cluster"
  database_name       = "dev"
  master_username     = "awsuser"
  master_password     = "TestPass123"  # Change this after import
  node_type           = "ra3.xlplus"
  cluster_type        = "single-node"
  
  iam_roles = [aws_iam_role.redshift_role.arn]
  
  publicly_accessible              = true
  encrypted                        = true
  automated_snapshot_retention_period = 1
  skip_final_snapshot              = true
  availability_zone_relocation_enabled = true
  
  tags = {
    Name        = "redshift-test-cluster"
    Environment = "Test"
  }
  
  # These will be populated during import
  lifecycle {
    ignore_changes = [master_password]
  }
}

output "cluster_endpoint" {
  value       = aws_redshift_cluster.main.endpoint
  description = "Redshift cluster endpoint"
}

output "cluster_jdbc_connection" {
  value       = "jdbc:redshift://${aws_redshift_cluster.main.endpoint}/${aws_redshift_cluster.main.database_name}"
  description = "JDBC connection string"
}

output "iam_role_arn" {
  value       = aws_iam_role.redshift_role.arn
  description = "IAM role ARN for Redshift"
}

