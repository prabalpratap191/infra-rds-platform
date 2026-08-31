output "master_secret_arn" {
  description = "ARN of master credentials secret"
  value       = aws_secretsmanager_secret.master.arn
}

output "master_secret_name" {
  description = "Name of master credentials secret"
  value       = aws_secretsmanager_secret.master.name
}

output "master_password" {
  description = "Master database password"
  value       = random_password.master.result
  sensitive   = true
}

output "secret_arns" {
  description = "Map of microservice names to secret ARNs"
  value = {
    for service, secret in aws_secretsmanager_secret.microservice :
    service => secret.arn
  }
}

output "secret_names" {
  description = "Map of microservice names to secret names"
  value = {
    for service, secret in aws_secretsmanager_secret.microservice :
    service => secret.name
  }
}

output "microservice_passwords" {
  description = "Map of microservice names to passwords"
  value = {
    for service, password in random_password.microservice :
    service => password.result
  }
  sensitive = true
}
