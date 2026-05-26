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

variable "alb_arn" {
  description = "ARN of the ALB to attach WAF to"
  type        = string
}

variable "rate_limit" {
  description = "Rate limit (requests per 5 minutes per IP)"
  type        = number
  default     = 2000
}

variable "enable_waf_logging" {
  description = "Enable WAF logging to CloudWatch"
  type        = bool
  default     = true
}
