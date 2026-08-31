output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "security_group_name" {
  description = "RDS security group name"
  value       = aws_security_group.rds.name
}

output "security_group_arn" {
  description = "RDS security group ARN"
  value       = aws_security_group.rds.arn
}
