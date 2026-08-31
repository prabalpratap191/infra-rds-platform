# Networking Module - DB Subnet Group
# Creates subnet group for RDS deployment across multiple availability zones

resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-${var.environment}-subnet-group"
  description = "Database subnet group for ${var.project_name} ${var.environment}"
  subnet_ids  = var.private_subnet_ids
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-subnet-group"
    }
  )
}
