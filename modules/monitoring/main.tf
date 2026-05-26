data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/nodejs"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "syslog" {
  name              = "/system/syslog"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "alb_access" {
  name              = "/aws/alb/access-logs"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/flowlogs/${var.project}-${var.environment}"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM Role for VPC Flow Logs
# -----------------------------------------------------------------------------
resource "aws_iam_role" "flow_logs" {
  name = "${var.project}-${var.environment}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project}-${var.environment}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# SNS Topic for Alarms
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.project}-${var.environment}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

# CPU > 80%
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = var.tags
}

# ALB 5xx > 10/min
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx errors exceed 10 per minute"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# Target 5xx (error rate proxy)
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "${var.project}-${var.environment}-target-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Target 5xx errors exceed threshold (error rate > 1%)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ASG Instance Count below minimum
resource "aws_cloudwatch_metric_alarm" "asg_instances_low" {
  alarm_name          = "${var.project}-${var.environment}-asg-low-instances"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Average"
  threshold           = var.min_size
  alarm_description   = "ASG in-service instances below minimum (${var.min_size})"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ASG CPU Utilization"
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]]
          period  = 300
          stat    = "Average"
          region  = data.aws_region.current.name
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "ASG Network Traffic"
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", var.asg_name],
            [".", "NetworkOut", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count"
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]]
          period  = 60
          stat    = "Sum"
          region  = data.aws_region.current.name
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "ALB HTTP Errors"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_ELB_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          period = 60
          stat   = "Sum"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Target Response Time"
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]]
          period  = 60
          stat    = "Average"
          region  = data.aws_region.current.name
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title = "Healthy / Unhealthy Hosts"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "UnHealthyHostCount", ".", "."]
          ]
          period = 60
          stat   = "Average"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title = "ASG Group Size"
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.asg_name],
            [".", "GroupDesiredCapacity", ".", "."],
            [".", "GroupMinSize", ".", "."],
            [".", "GroupMaxSize", ".", "."]
          ]
          period = 60
          stat   = "Average"
          region = data.aws_region.current.name
          view   = "timeSeries"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudTrail
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.project}-${var.environment}-cloudtrail-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-cloudtrail"
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "cloudtrail-lifecycle"
    status = "Enabled"
    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.project}-${var.environment}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_iam_role" "cloudtrail" {
  name = "${var.project}-${var.environment}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${var.project}-${var.environment}-cloudtrail-cw"
  role = aws_iam_role.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.project}-${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail.arn

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-trail"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}
