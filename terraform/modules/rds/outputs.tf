output "instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.this.id
}

output "instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS instance address"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "engine_version" {
  description = "RDS engine version"
  value       = aws_db_instance.this.engine_version_actual
}

output "resource_id" {
  description = "RDS resource ID"
  value       = aws_db_instance.this.resource_id
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "master_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
  sensitive   = false
}
