# AWS Provider Configuration

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = "RDS-Platform"
      ManagedBy     = "Terraform"
      Owner         = "DevOps"
      CostCenter    = "Engineering"
      Repository    = "infra-rds-platform"
      LastUpdated   = timestamp()
    }
  }
}

# Random provider for password generation
provider "random" {}

# Data sources for current AWS account information
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}
