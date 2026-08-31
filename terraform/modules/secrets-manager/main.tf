# Secrets Manager Module
# Creates and manages database credentials in AWS Secrets Manager

# Generate random password for master database user
resource "random_password" "master" {
  length  = 32
  special = true
  # Avoid characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Master database secret
resource "aws_secretsmanager_secret" "master" {
  name        = "rds/${var.environment}/master-credentials"
  description = "Master credentials for RDS instance"
  
  recovery_window_in_days = 7
  
  tags = merge(
    var.tags,
    {
      Name        = "rds-${var.environment}-master-secret"
      Database    = "master"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.master.result
    engine   = "postgres"
    port     = 5432
  })
}

# Generate random passwords for each microservice
resource "random_password" "microservice" {
  for_each = var.microservices
  
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Secrets for each microservice database user
resource "aws_secretsmanager_secret" "microservice" {
  for_each = var.microservices
  
  name        = "rds/${var.environment}/${each.key}"
  description = "Database credentials for ${each.key}"
  
  recovery_window_in_days = 7
  
  tags = merge(
    var.tags,
    {
      Name        = "rds-${var.environment}-${each.key}-secret"
      Microservice = each.key
      Database    = each.value.database_name
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "microservice" {
  for_each = var.microservices
  
  secret_id = aws_secretsmanager_secret.microservice[each.key].id
  secret_string = jsonencode({
    username = each.value.username
    password = random_password.microservice[each.key].result
    database = each.value.database_name
    engine   = "postgres"
    port     = 5432
  })
}
