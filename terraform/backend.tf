# Backend Configuration for Terraform State Management
# This configuration stores Terraform state in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "terraform-state-rds-platform-${var.environment}"
    key            = "rds-platform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-rds-platform"
    
    # Server-side encryption
    kms_key_id = "alias/terraform-state-key"
    
    # Versioning for state recovery
    versioning = true
  }
  
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Note: Before using this backend, create the S3 bucket and DynamoDB table:
# aws s3api create-bucket --bucket terraform-state-rds-platform-dev --region us-east-1
# aws s3api put-bucket-versioning --bucket terraform-state-rds-platform-dev --versioning-configuration Status=Enabled
# aws s3api put-bucket-encryption --bucket terraform-state-rds-platform-dev --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
# aws dynamodb create-table --table-name terraform-state-lock-rds-platform --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 --region us-east-1
