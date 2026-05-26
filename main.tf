locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Monitoring (created first — provides log groups and IAM role for VPC flow logs)
# -----------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  environment    = var.environment
  project        = var.project
  tags           = local.common_tags
  kms_key_arn    = module.security.kms_key_arn
  asg_name       = module.compute.asg_name
  alb_arn_suffix = module.alb.alb_arn_suffix
  min_size       = var.min_size
  alarm_email    = var.alarm_email
}

# -----------------------------------------------------------------------------
# VPC & Networking
# -----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  environment           = var.environment
  project               = var.project
  tags                  = local.common_tags
  vpc_cidr              = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  isolated_subnet_cidrs = var.isolated_subnet_cidrs
  flow_log_group_arn    = module.monitoring.flow_log_group_arn
  flow_log_role_arn     = module.monitoring.flow_log_role_arn
}

# -----------------------------------------------------------------------------
# Security (SGs, IAM, KMS, SSM)
# -----------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  environment      = var.environment
  project          = var.project
  tags             = local.common_tags
  vpc_id           = module.vpc.vpc_id
  app_port         = var.app_port
  allowed_db_ports = var.allowed_db_ports
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  environment         = var.environment
  project             = var.project
  tags                = local.common_tags
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  security_group_id   = module.security.alb_sg_id
  acm_certificate_arn = var.acm_certificate_arn
  app_port            = var.app_port
  kms_key_arn         = module.security.kms_key_arn
  enable_stickiness   = var.enable_stickiness
}

# -----------------------------------------------------------------------------
# Compute (Launch Template + ASG)
# -----------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  environment               = var.environment
  project                   = var.project
  tags                      = local.common_tags
  ami_id                    = var.ami_id
  instance_type             = var.instance_type
  iam_instance_profile_name = module.security.iam_instance_profile_name
  security_group_id         = module.security.ec2_sg_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  target_group_arn                = module.alb.target_group_arn
  alb_target_group_resource_label = module.alb.alb_target_group_resource_label
  kms_key_arn                     = module.security.kms_key_arn
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  cpu_target                = var.cpu_target
  enable_scheduled_scaling  = var.enable_scheduled_scaling
  app_s3_bucket             = var.app_s3_bucket
  key_name                  = var.key_name
}

# -----------------------------------------------------------------------------
# WAF
# -----------------------------------------------------------------------------
module "waf" {
  source = "./modules/waf"

  environment        = var.environment
  project            = var.project
  tags               = local.common_tags
  alb_arn            = module.alb.alb_arn
  rate_limit         = var.waf_rate_limit
  enable_waf_logging = var.enable_waf_logging
}

# DNS moduke

module "dns" {
  source = "./modules/dns"

  domain_name   = var.domain_name
  app_domain    = var.app_domain

  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}
