variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "eks_security_group_id" {
  description = "Security group ID of EKS worker nodes"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group ID of bastion host"
  type        = string
  default     = ""
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
