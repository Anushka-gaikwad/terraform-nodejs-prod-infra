variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "allowed_db_ports" {
  description = "Database ports to allow"
  type        = list(number)
  default     = [5432]
}
