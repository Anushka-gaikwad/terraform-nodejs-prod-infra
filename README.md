# Production-Grade Node.js Infrastructure on AWS (Terraform)

This repository contains Infrastructure as Code (Terraform) to deploy a secure, scalable, and production-ready Node.js REST API on AWS using EC2 Auto Scaling, ALB, WAF, Route 53, ACM, and CloudWatch.

The goal is to implement real-world AWS production architecture principles: high availability, security, observability, and zero-downtime deployments.

---

## 🌐 End-to-End Architecture Flow
User
↓
Route 53 (DNS)
↓
AWS WAF (Security Filtering)
↓
Application Load Balancer (HTTPS via ACM)
↓
Target Group
↓
EC2 Auto Scaling Group (Private Subnets)
↓
Node.js Application
↓
CloudWatch Logs + Metrics + CloudTrail


---

## 🧠 System Design Summary

- Fully multi-AZ architecture
- No direct EC2 exposure to internet
- All traffic encrypted via HTTPS (ACM)
- Auto Scaling based on CPU utilization
- Centralized logging + monitoring
- DNS-based access via Route 53
- Secure-by-default network segmentation

---

## 🌍 Networking & VPC Design

### VPC
- Custom VPC with `/16 CIDR`
- Multi-AZ (minimum 2 Availability Zones)

### Subnets
- Public Subnets:
  - ALB
  - NAT Gateway
- Private Subnets:
  - EC2 Auto Scaling Group
- (Optional) Isolated Subnets:
  - Database layer

### Routing
- Internet Gateway → Public Subnets
- NAT Gateway → Private Subnets (outbound only)

### DNS (Route 53)
- Hosted Zone managed in Route 53
- Domain maps to ALB using Alias record:

anushka-prod.com → ALB DNS


This is the **real production entry point** for users.

---

## 🔐 Security & SSL (ACM + WAF)

### AWS Certificate Manager (ACM)
- TLS certificate attached to ALB
- Enables HTTPS (port 443)
- HTTP → HTTPS redirect enforced

### AWS WAF
- Attached to ALB
- Protection rules:
  - SQL Injection protection
  - XSS protection
  - Rate limiting (2000 req / 5 min / IP)

### IAM & Secrets
- EC2 uses IAM Instance Profile (no hardcoded credentials)
- Secrets stored in SSM Parameter Store / Secrets Manager

### Network Security
- No SSH access (SSM Session Manager only)
- Security Groups follow least privilege

---

## ⚙️ Compute Layer (EC2 + ASG)

### Launch Template
- Amazon Linux 2023 AMI
- Node.js installed via user data
- IAM role attached
- EBS encryption enabled

### Auto Scaling Group
- Multi-AZ deployment
- Min / Desired / Max capacity defined
- CPU-based scaling (target 60%)
- Instance Refresh for zero-downtime deployments

### Health Checks
- ALB health checks control instance lifecycle
- Unhealthy instances automatically replaced

---

## ⚖️ Load Balancer (ALB)

- Internet-facing Application Load Balancer
- HTTPS listener (443 only)
- Target group connected to ASG
- HTTP → HTTPS redirect enabled
- Access logs stored in S3 bucket

---

## 🛡️ Security Architecture

- AWS WAF on ALB
- KMS encryption for:
  - EBS volumes
  - S3 buckets
  - CloudWatch logs
- VPC Flow Logs enabled for traffic auditing
- No public EC2 access

---

## 📊 Monitoring & Observability

### CloudWatch
- Log Groups:
  - /app/nodejs
  - /system/syslog
  - /aws/alb/access-logs

### Metrics
- CPU utilization
- Request count
- 4xx / 5xx errors

### Alarms
- CPU > 80%
- ALB 5xx spike alerts
- ASG unhealthy instance count

### Dashboard
- Real-time infrastructure visibility

### CloudTrail
- Enabled for all regions
- Logs stored in S3 with integrity validation

---

## 🚀 Deployment (Terraform)

### Initialize
```bash
terraform init

terraform plan -var-file=environments/staging.tfvars
terraform plan -var-file=environments/production.tfvars

terraform apply -var-file=environments/production.tfvars

# makefile (optinal)
make plan ENV=staging
make apply ENV=production
 
## Repository structure 

modules/
├── vpc/         # Networking (VPC, subnets, NAT, routes)
├── alb/         # Load balancer + HTTPS + logs
├── route53/     # DNS records (domain → ALB)
├── acm/         # SSL certificate management
├── security/    # IAM, SGs, KMS, SSM
├── compute/     # EC2 Launch Template + ASG
├── waf/         # Web Application Firewall rules
└── monitoring/  # CloudWatch, alarms, dashboards, CloudTrail
