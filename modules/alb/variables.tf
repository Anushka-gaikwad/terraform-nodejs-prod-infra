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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "enable_stickiness" {
  description = "Enable target group stickiness"
  type        = bool
  default     = false
}
