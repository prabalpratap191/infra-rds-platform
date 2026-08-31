# Main Terraform Configuration for RDS Platform
# This orchestrates all modules to create the complete infrastructure

locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
  
  db_identifier = "${var.project_name}-${var.environment}-postgres"
}

# Networking Module - DB Subnet Group
module "networking" {
  source = "./modules/networking"
  
  environment         = var.environment
  project_name        = var.project_name
  vpc_id              = var.vpc_id
  private_subnet_ids  = var.private_subnet_ids
  
  tags = local.common_tags
}

# Security Group Module
module "security_group" {
  source = "./modules/security-group"
  
  environment                    = var.environment
  project_name                   = var.project_name
  vpc_id                         = var.vpc_id
  db_port                        = var.db_port
  eks_security_group_id          = var.eks_security_group_id
  bastion_security_group_id      = var.bastion_security_group_id
  additional_security_group_ids  = var.additional_security_group_ids
  
  tags = local.common_tags
}

# Secrets Manager Module
module "secrets_manager" {
  source = "./modules/secrets-manager"
  
  environment       = var.environment
  project_name      = var.project_name
  microservices     = var.microservices
  db_master_username = var.db_master_username
  
  tags = local.common_tags
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  # Instance Configuration
  identifier            = local.db_identifier
  environment           = var.environment
  project_name          = var.project_name
  instance_class        = var.db_instance_class
  engine_version        = var.db_engine_version
  
  # Storage Configuration
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = var.db_storage_type
  iops                  = var.db_iops
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id
  
  # Database Configuration
  db_name               = var.db_name
  master_username       = var.db_master_username
  master_password       = module.secrets_manager.master_password
  port                  = var.db_port
  parameter_group_family = var.db_parameter_family
  
  # Network Configuration
  db_subnet_group_name  = module.networking.subnet_group_name
  vpc_security_group_ids = [module.security_group.security_group_id]
  publicly_accessible   = var.publicly_accessible
  multi_az              = var.multi_az
  
  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  copy_tags_to_snapshot  = var.copy_tags_to_snapshot
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = "${local.db_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Monitoring Configuration
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period
  
  # Microservices Configuration
  microservices         = var.microservices
  microservice_passwords = module.secrets_manager.microservice_passwords
  
  tags = local.common_tags
  
  depends_on = [
    module.networking,
    module.security_group,
    module.secrets_manager
  ]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  environment               = var.environment
  project_name              = var.project_name
  db_instance_id            = module.rds.instance_id
  db_instance_class         = var.db_instance_class
  
  # Alarm Thresholds
  cpu_threshold             = var.alarm_cpu_threshold
  memory_threshold          = var.alarm_memory_threshold
  storage_threshold         = var.alarm_storage_threshold
  connection_threshold      = var.alarm_connection_threshold
  
  # SNS Topic for Alerts
  sns_topic_arn            = var.alarm_sns_topic_arn
  
  tags = local.common_tags
  
  depends_on = [module.rds]
}
