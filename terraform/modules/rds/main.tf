# RDS Module - PostgreSQL Instance and Configuration
# Creates RDS instance, parameter group, option group, and initializes databases

# IAM role for enhanced monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# DB Parameter Group
resource "aws_db_parameter_group" "this" {
  name   = "${var.project_name}-${var.environment}-postgres-params"
  family = var.parameter_group_family
  
  description = "Custom parameter group for ${var.project_name} ${var.environment}"
  
  # Performance and connection parameters
  # Note: shared_preload_libraries is a static parameter requiring DB restart
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }
  
  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
  }
  
  parameter {
    name  = "log_statement"
    value = "ddl"
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking more than 1 second
  }
  
  parameter {
    name  = "max_connections"
    value = "200"
  }
  
  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/32768}" # 25% of RAM
  }
  
  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory/16384}" # 50% of RAM
  }
  
  parameter {
    name  = "maintenance_work_mem"
    value = "524288" # 512MB
  }
  
  parameter {
    name  = "work_mem"
    value = "10240" # 10MB
  }
  
  # SSL Configuration
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  
  # Autovacuum settings
  parameter {
    name  = "autovacuum"
    value = "1"
  }
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-postgres-params"
    }
  )
}

# DB Option Group
resource "aws_db_option_group" "this" {
  name                     = "${var.project_name}-${var.environment}-postgres-options"
  option_group_description = "Option group for ${var.project_name} ${var.environment}"
  engine_name              = "postgres"
  major_engine_version     = split(".", var.engine_version)[0]
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-postgres-options"
    }
  )
}

# RDS Instance
resource "aws_db_instance" "this" {
  # Instance identification
  identifier = var.identifier
  
  # Engine configuration
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  
  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id != "" ? var.kms_key_id : null
  iops                  = var.iops
  
  # Database configuration
  db_name  = var.db_name
  username = var.master_username
  password = var.master_password
  port     = var.port
  
  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.this.name
  option_group_name    = aws_db_option_group.this.name
  
  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az
  
  # Backup configuration
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = var.copy_tags_to_snapshot
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  deletion_protection       = var.deletion_protection
  
  # Monitoring configuration
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  
  # Allow major version upgrades
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  
  # Apply changes immediately (set to false for production)
  apply_immediately = var.environment == "dev" ? true : false
  
  tags = merge(
    var.tags,
    {
      Name = var.identifier
    }
  )
  
  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}
