variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "db_master_username" {
  description = "Master database username"
  type        = string
}

variable "microservices" {
  description = "Microservices configuration"
  type = map(object({
    database_name = string
    username      = string
    namespace     = string
  }))
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
