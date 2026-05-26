# Staging Environment Configuration
environment = "staging"
project     = "nodejs-app"
owner       = "devops-team"
cost_center = "engineering"
aws_region  = "ap-south-1"

# Networking
vpc_cidr              = "10.1.0.0/16"
azs                   = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24"]
isolated_subnet_cidrs = ["10.1.21.0/24", "10.1.22.0/24"]

# Compute — smaller footprint for staging
ami_id                   = "ami-0abcdef1234567890" # Replace with actual Amazon Linux 2023 AMI
instance_type            = "t3.small"
app_port                 = 3000
min_size                 = 1
desired_capacity         = 1
max_size                 = 3
cpu_target               = 70
enable_scheduled_scaling = false
key_name                 = ""
app_s3_bucket            = ""

# Load Balancer
acm_certificate_arn = "arn:aws:acm:ap-south-1:123456789012:certificate/xxxxx" # Replace
enable_stickiness   = false

# WAF
waf_rate_limit     = 2000
enable_waf_logging = true

# Monitoring
alarm_email = "dev-team@example.com" # Replace

# Database
allowed_db_ports = [5432]
