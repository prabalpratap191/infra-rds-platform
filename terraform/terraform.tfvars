# Development Environment Configuration
# Copy this file to terraform.tfvars and update with your actual values

# Environment Configuration
environment  = "dev"
aws_region   = "us-east-1"
project_name = "rds-platform"

# Network Configuration
# REQUIRED: Update these with your actual VPC and subnet IDs
vpc_id = "vpc-04c700d412f86947c"  # Your VPC ID
private_subnet_ids = [
  "subnet-041e40e6c16be97ef",
  "subnet-076969b707fa90d44"
]

# Security Groups
# REQUIRED: Update with your actual security group IDs
eks_security_group_id     = "eks-cluster-sg*"  # EKS worker nodes security group
bastion_security_group_id = ""  # Bastion host security group (optional)
additional_security_group_ids = []  # Add any additional security groups

# RDS Instance Configuration
db_instance_class       = "db.t3.medium"  # db.t3.small for minimal cost
db_engine_version       = "15.4"
db_allocated_storage    = 100
db_max_allocated_storage = 500
db_storage_type         = "gp3"
multi_az                = false  # Set to true for production
publicly_accessible     = false  # Always false for security

# Database Configuration
db_port            = 5432
db_name            = "postgres"
db_master_username = "postgres"
db_parameter_family = "postgres15"

# Backup Configuration
backup_retention_period = 7
backup_window          = "03:00-04:00"
maintenance_window     = "sun:04:00-sun:05:00"
copy_tags_to_snapshot  = true
deletion_protection    = false  # Set to true for production
skip_final_snapshot    = false  # Set to false for production

# Encryption
storage_encrypted = true
kms_key_id        = ""  # Leave empty to use default AWS managed key

# Monitoring
enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
monitoring_interval              = 60
performance_insights_enabled     = true
performance_insights_retention_period = 7

# CloudWatch Alarms
alarm_cpu_threshold        = 80
alarm_memory_threshold     = 1000000000  # 1GB
alarm_storage_threshold    = 10000000000 # 10GB
alarm_connection_threshold = 80
alarm_sns_topic_arn        = ""  # SNS topic ARN for alarm notifications (optional)

# Microservices Configuration (default values - can be customized)
microservices = {
  customer-service = {
    database_name = "customer_db"
    username      = "customer_user"
    namespace     = "customer-service-ns"
  }
  order-service = {
    database_name = "order_db"
    username      = "order_user"
    namespace     = "order-service-ns"
  }
  catalog-service = {
    database_name = "catalog_db"
    username      = "catalog_user"
    namespace     = "catalog-service-ns"
  }
  order-history-service = {
    database_name = "order_history_db"
    username      = "order_history_user"
    namespace     = "order-history-service-ns"
  }
  notification-service = {
    database_name = "notification_db"
    username      = "notification_user"
    namespace     = "notification-service-ns"
  }
}

# Additional Tags
additional_tags = {
  Team        = "Platform"
  Application = "Microservices"
  Compliance  = "GDPR"
}
