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

variable "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  type        = string
}

variable "asg_name" {
  description = "Auto Scaling Group name for alarm dimensions"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for alarm dimensions"
  type        = string
}

variable "min_size" {
  description = "Minimum ASG size for alarm threshold"
  type        = number
  default     = 2
}

variable "alarm_email" {
  description = "Email for alarm notifications"
  type        = string
  default     = ""
}
