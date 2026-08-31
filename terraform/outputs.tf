# RDS Instance Outputs

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.instance_id
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = module.rds.instance_arn
}

output "rds_endpoint" {
  description = "RDS instance endpoint (hostname:port)"
  value       = module.rds.endpoint
  sensitive   = false
}

output "rds_address" {
  description = "RDS instance hostname"
  value       = module.rds.address
  sensitive   = false
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.port
}

output "rds_engine_version" {
  description = "RDS engine version"
  value       = module.rds.engine_version
}

output "rds_resource_id" {
  description = "RDS resource ID"
  value       = module.rds.resource_id
}

# Database Information

output "master_database_name" {
  description = "Master database name"
  value       = var.db_name
}

output "microservice_databases" {
  description = "Map of microservice names to their database names"
  value = {
    for service, config in var.microservices :
    service => config.database_name
  }
}

output "microservice_usernames" {
  description = "Map of microservice names to their database usernames"
  value = {
    for service, config in var.microservices :
    service => config.username
  }
  sensitive = false
}

# Security Group Outputs

output "rds_security_group_id" {
  description = "Security group ID for RDS instance"
  value       = module.security_group.security_group_id
}

output "rds_security_group_name" {
  description = "Security group name for RDS instance"
  value       = module.security_group.security_group_name
}

# Subnet Group Outputs

output "db_subnet_group_name" {
  description = "Database subnet group name"
  value       = module.networking.subnet_group_name
}

output "db_subnet_group_id" {
  description = "Database subnet group ID"
  value       = module.networking.subnet_group_id
}

# Secrets Manager Outputs

output "secrets_manager_arns" {
  description = "Map of microservice names to their Secrets Manager ARNs"
  value = {
    for service, config in var.microservices :
    service => module.secrets_manager.secret_arns[service]
  }
  sensitive = false
}

output "secrets_manager_names" {
  description = "Map of microservice names to their Secrets Manager secret names"
  value = {
    for service, config in var.microservices :
    service => module.secrets_manager.secret_names[service]
  }
}

output "master_secret_arn" {
  description = "Master database credentials secret ARN"
  value       = module.secrets_manager.master_secret_arn
  sensitive   = false
}

# Monitoring Outputs

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = module.monitoring.log_group_name
}

output "cloudwatch_alarm_arns" {
  description = "CloudWatch alarm ARNs"
  value       = module.monitoring.alarm_arns
}

# Connection Information for Applications

output "jdbc_connection_strings" {
  description = "JDBC connection strings for each microservice"
  value = {
    for service, config in var.microservices :
    service => "jdbc:postgresql://${module.rds.address}:${module.rds.port}/${config.database_name}"
  }
}

output "spring_boot_datasource_config" {
  description = "Spring Boot datasource configuration template"
  value = {
    for service, config in var.microservices :
    service => {
      url      = "jdbc:postgresql://${module.rds.address}:${module.rds.port}/${config.database_name}"
      username = config.username
      password = "{{resolve:secretsmanager:${module.secrets_manager.secret_names[service]}:SecretString:password}}"
    }
  }
  sensitive = true
}

# Kubernetes ConfigMap Values

output "kubernetes_configmap_data" {
  description = "Data for Kubernetes ConfigMaps"
  value = {
    for service, config in var.microservices :
    service => {
      DB_HOST = module.rds.address
      DB_PORT = tostring(module.rds.port)
      DB_NAME = config.database_name
    }
  }
}

# External Secrets Operator Configuration

output "external_secrets_config" {
  description = "Configuration for External Secrets Operator"
  value = {
    for service, config in var.microservices :
    service => {
      secret_name = module.secrets_manager.secret_names[service]
      secret_arn  = module.secrets_manager.secret_arns[service]
      region      = var.aws_region
      namespace   = config.namespace
    }
  }
}

# Summary Output

output "deployment_summary" {
  description = "Deployment summary information"
  value = {
    environment           = var.environment
    region                = var.aws_region
    rds_endpoint          = module.rds.endpoint
    engine_version        = module.rds.engine_version
    instance_class        = var.db_instance_class
    multi_az              = var.multi_az
    storage_encrypted     = var.storage_encrypted
    allocated_storage_gb  = var.db_allocated_storage
    microservices_count   = length(var.microservices)
    backup_retention_days = var.backup_retention_period
    maintenance_window    = var.maintenance_window
  }
}
