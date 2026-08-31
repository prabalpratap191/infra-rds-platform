# Security Group Module for RDS
# Creates security group with ingress rules for EKS and bastion access

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.vpc_id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )
}

# Ingress rule for EKS worker nodes
resource "aws_security_group_rule" "rds_ingress_eks" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.eks_security_group_id
  description              = "Allow PostgreSQL access from EKS worker nodes"
}

# Ingress rule for bastion host (if provided)
resource "aws_security_group_rule" "rds_ingress_bastion" {
  count = var.bastion_security_group_id != "" ? 1 : 0
  
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.bastion_security_group_id
  description              = "Allow PostgreSQL access from bastion host"
}

# Additional ingress rules for other security groups
resource "aws_security_group_rule" "rds_ingress_additional" {
  count = length(var.additional_security_group_ids)
  
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.additional_security_group_ids[count.index]
  description              = "Allow PostgreSQL access from additional security group ${count.index + 1}"
}

# Egress rule - Allow all outbound traffic (required for RDS)
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}
