output "subnet_group_name" {
  description = "Database subnet group name"
  value       = aws_db_subnet_group.this.name
}

output "subnet_group_id" {
  description = "Database subnet group ID"
  value       = aws_db_subnet_group.this.id
}

output "subnet_group_arn" {
  description = "Database subnet group ARN"
  value       = aws_db_subnet_group.this.arn
}
