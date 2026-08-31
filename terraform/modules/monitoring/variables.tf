variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "db_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "cpu_threshold" {
  description = "CPU utilization threshold"
  type        = number
}

variable "memory_threshold" {
  description = "Freeable memory threshold"
  type        = number
}

variable "storage_threshold" {
  description = "Free storage threshold"
  type        = number
}

variable "connection_threshold" {
  description = "Database connections threshold"
  type        = number
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarms"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
