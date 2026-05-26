# Production-Ready Node.js Infrastructure on AWS

Terraform IaC for deploying a scalable, secure Node.js REST API on EC2 with enterprise production standards.

## Architecture

```
Internet → WAF → ALB (public subnets) → EC2 ASG (private subnets) → DB (isolated subnets)
                                              ↓
                                     NAT Gateway → Internet (egress only)
```

**Key components:**
- **VPC**: Custom /16 VPC across 2 AZs with public, private, and isolated subnets
- **ALB**: Application Load Balancer with HTTPS (ACM), HTTP→HTTPS redirect, access logs to S3
- **ASG**: Auto Scaling Group with launch template, target tracking (CPU 60%), scheduled scaling, instance refresh for zero-downtime deploys
- **WAF**: AWS WAF with Core Rule Set, SQL injection, XSS, and rate-limiting (2000 req/5min/IP)
- **Security**: Least-privilege SGs, IAM instance profile, KMS encryption, SSM Session Manager (no SSH), IMDSv2 enforced
- **Monitoring**: CloudWatch agent, log groups (/app/nodejs, /system/syslog), alarms (CPU, 5xx, ASG health), operational dashboard
- **CloudTrail**: Multi-region trail with S3 storage and log file validation
- **VPC Flow Logs**: Network traffic auditing to CloudWatch Logs

## Module Structure

```
modules/
├── vpc/         # VPC, subnets, IGW, NAT, route tables, NACLs, flow logs
├── security/    # Security groups, IAM roles, KMS, SSM parameters
├── alb/         # ALB, target group, HTTPS listener, access logs S3 bucket
├── compute/     # Launch template, ASG, scaling policies, CloudWatch agent config
├── waf/         # WAF WebACL, managed rules, rate limiting
└── monitoring/  # CloudWatch log groups, alarms, dashboard, CloudTrail
```

## Usage

```bash
# Initialize
terraform init

# Plan for staging
terraform plan -var-file=environments/staging.tfvars

# Plan for production
terraform plan -var-file=environments/production.tfvars

# Apply
terraform apply -var-file=environments/production.tfvars
```

Or use the Makefile:
```bash
make plan ENV=staging
make apply ENV=staging
```

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0
3. An ACM certificate ARN for HTTPS
4. An AMI ID (Amazon Linux 2023 recommended)

## Required Variables

| Variable | Description |
|---|---|
| `environment` | Environment name (staging/production) |
| `ami_id` | Amazon Linux 2023 AMI ID |
| `acm_certificate_arn` | ACM certificate ARN for HTTPS |

Update `environments/production.tfvars` and `environments/staging.tfvars` with actual values before deploying.
