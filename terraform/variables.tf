# Core Infrastructure Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "rds-platform"
}

# Network Variables

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS subnet group"
  type        = list(string)
  
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for RDS subnet group."
  }
}

variable "eks_security_group_id" {
  description = "Security group ID of EKS worker nodes"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group ID of bastion host for SSH access"
  type        = string
  default     = ""
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs that need database access"
  type        = list(string)
  default     = []
}

# RDS Instance Configuration

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 100
  
  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB."
  }
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 500
}

variable "db_storage_type" {
  description = "Storage type (gp3, gp2, io1)"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.db_storage_type)
    error_message = "Storage type must be gp2, gp3, io1, or io2."
  }
}

variable "db_iops" {
  description = "IOPS for io1/io2 storage type"
  type        = number
  default     = null
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Make database publicly accessible (should be false for production)"
  type        = bool
  default     = false
}

# Database Configuration

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Default database name (master database)"
  type        = string
  default     = "postgres"
}

variable "db_master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
}

variable "db_parameter_family" {
  description = "Database parameter group family"
  type        = string
  default     = "postgres16"
}

# Microservices Database Configuration

variable "microservices" {
  description = "List of microservices with their database configurations"
  type = map(object({
    database_name = string
    username      = string
    namespace     = string
  }))
  
  default = {
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
}

# Backup Configuration

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to snapshots"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

# Encryption

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (leave empty to use default)"
  type        = string
  default     = ""
}

# Monitoring

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
  
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60 seconds."
  }
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

# CloudWatch Alarms

variable "alarm_cpu_threshold" {
  description = "CPU utilization threshold for alarms (%)"
  type        = number
  default     = 80
}

variable "alarm_memory_threshold" {
  description = "Freeable memory threshold for alarms (bytes)"
  type        = number
  default     = 1000000000 # 1GB
}

variable "alarm_storage_threshold" {
  description = "Free storage space threshold for alarms (bytes)"
  type        = number
  default     = 10000000000 # 10GB
}

variable "alarm_connection_threshold" {
  description = "Database connections threshold for alarms"
  type        = number
  default     = 80
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}

# Tags

variable "additional_tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
