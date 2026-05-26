# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "isolated_subnet_ids" {
  description = "IDs of isolated/database subnets"
  value       = module.vpc.isolated_subnet_ids
}

# -----------------------------------------------------------------------------
# Load Balancer
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB (for Route 53 alias records)"
  value       = module.alb.alb_zone_id
}

# -----------------------------------------------------------------------------
# Compute
# -----------------------------------------------------------------------------
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------
output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = module.security.kms_key_arn
}

# -----------------------------------------------------------------------------
# WAF
# -----------------------------------------------------------------------------
output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = module.waf.web_acl_arn
}

# -----------------------------------------------------------------------------
# Monitoring
# -----------------------------------------------------------------------------
output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = module.monitoring.sns_topic_arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}
