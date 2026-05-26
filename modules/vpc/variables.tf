variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "isolated_subnet_cidrs" {
  description = "CIDR blocks for isolated/database subnets"
  type        = list(string)
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "flow_log_group_arn" {
  description = "ARN of the CloudWatch log group for VPC flow logs"
  type        = string
}

variable "flow_log_role_arn" {
  description = "ARN of the IAM role for VPC flow logs"
  type        = string
}
