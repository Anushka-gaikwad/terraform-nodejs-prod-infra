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

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ASG"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "alb_target_group_resource_label" {
  description = "ALB/TG resource label for ALBRequestCountPerTarget metric (format: app/alb-name/alb-id/targetgroup/tg-name/tg-id)"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS encryption"
  type        = string
}

variable "min_size" {
  description = "Minimum ASG size"
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired ASG capacity"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum ASG size"
  type        = number
  default     = 6
}

variable "cpu_target" {
  description = "Target CPU utilization for scaling"
  type        = number
  default     = 60
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling"
  type        = bool
  default     = false
}

variable "app_s3_bucket" {
  description = "S3 bucket containing app artifact"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name (optional)"
  type        = string
  default     = ""
}
