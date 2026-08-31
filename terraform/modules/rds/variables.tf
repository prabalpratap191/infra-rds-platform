variable "identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling"
  type        = number
}

variable "storage_type" {
  description = "Storage type"
  type        = string
}

variable "iops" {
  description = "IOPS for io1/io2 storage"
  type        = number
  default     = null
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "master_username" {
  description = "Master username"
  type        = string
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Database port"
  type        = number
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "VPC security group IDs"
  type        = list(string)
}

variable "publicly_accessible" {
  description = "Make database publicly accessible"
  type        = bool
}

variable "multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
}

variable "backup_retention_period" {
  description = "Backup retention period"
  type        = number
}

variable "backup_window" {
  description = "Backup window"
  type        = string
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to snapshots"
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot"
  type        = bool
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
}

variable "enabled_cloudwatch_logs_exports" {
  description = "CloudWatch logs to export"
  type        = list(string)
}

variable "monitoring_interval" {
  description = "Monitoring interval"
  type        = number
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period"
  type        = number
}

variable "microservices" {
  description = "Microservices configuration"
  type = map(object({
    database_name = string
    username      = string
    namespace     = string
  }))
}

variable "microservice_passwords" {
  description = "Microservice passwords"
  type        = map(string)
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
