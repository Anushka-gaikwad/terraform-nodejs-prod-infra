data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project}-${var.environment}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
}

resource "aws_security_group_rule" "alb_egress_to_ec2" {
  type                     = "egress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.alb.id
  description              = "To EC2 app instances"
}

# EC2 Security Group
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project}-${var.environment}-ec2-"
  description = "Security group for EC2 application instances"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-ec2-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ec2_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ec2.id
  description              = "From ALB on app port"
}

resource "aws_security_group_rule" "ec2_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
  description       = "HTTPS outbound (apt/npm/SSM)"
}

resource "aws_security_group_rule" "ec2_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
  description       = "HTTP outbound (package repos)"
}

resource "aws_security_group_rule" "ec2_egress_to_db" {
  count                    = length(var.allowed_db_ports)
  type                     = "egress"
  from_port                = var.allowed_db_ports[count.index]
  to_port                  = var.allowed_db_ports[count.index]
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
  security_group_id        = aws_security_group.ec2.id
  description              = "To DB on port ${var.allowed_db_ports[count.index]}"
}

# Database Security Group
resource "aws_security_group" "db" {
  name_prefix = "${var.project}-${var.environment}-db-"
  description = "Security group for database tier"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_ingress_from_ec2" {
  count                    = length(var.allowed_db_ports)
  type                     = "ingress"
  from_port                = var.allowed_db_ports[count.index]
  to_port                  = var.allowed_db_ports[count.index]
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.db.id
  description              = "From EC2 on port ${var.allowed_db_ports[count.index]}"
}

# -----------------------------------------------------------------------------
# IAM Role for EC2 Instances
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# S3 read-only for app artifact pull
resource "aws_iam_role_policy" "s3_app_read" {
  name = "${var.project}-${var.environment}-s3-app-read"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = var.tags
}

# -----------------------------------------------------------------------------
# KMS Key
# -----------------------------------------------------------------------------
resource "aws_kms_key" "main" {
  description             = "KMS key for ${var.project}-${var.environment} encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project}-${var.environment}-key"
  target_key_id = aws_kms_key.main.key_id
}

# -----------------------------------------------------------------------------
# SSM Parameters for App Config
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "app_port" {
  name      = "/${var.project}/${var.environment}/app/port"
  type      = "String"
  value     = tostring(var.app_port)
  overwrite = true
  tags      = var.tags
}

resource "aws_ssm_parameter" "node_env" {
  name      = "/${var.project}/${var.environment}/app/node_env"
  type      = "String"
  value     = var.environment == "production" ? "production" : "development"
  overwrite = true
  tags      = var.tags
}
