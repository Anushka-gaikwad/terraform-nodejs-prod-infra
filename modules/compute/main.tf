data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# CloudWatch Agent Configuration in SSM
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "cw_agent_config" {
  name      = "/${var.project}/${var.environment}/cloudwatch-agent/config"
  type      = "String"
  overwrite = true

  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path         = "/opt/app/logs/app.log"
              log_group_name    = "/app/nodejs"
              log_stream_name   = "{instance_id}/app"
              retention_in_days = 30
            },
            {
              file_path         = "/opt/app/logs/error.log"
              log_group_name    = "/app/nodejs"
              log_stream_name   = "{instance_id}/error"
              retention_in_days = 30
            },
            {
              file_path         = "/var/log/messages"
              log_group_name    = "/system/syslog"
              log_stream_name   = "{instance_id}/syslog"
              retention_in_days = 30
            }
          ]
        }
      }
    }
    metrics = {
      namespace = "${var.project}/${var.environment}"
      metrics_collected = {
        cpu = {
          measurement                 = ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"]
          metrics_collection_interval = 60
          totalcpu                    = true
        }
        mem = {
          measurement                 = ["mem_used_percent", "mem_available_percent"]
          metrics_collection_interval = 60
        }
        disk = {
          measurement                 = ["disk_used_percent"]
          metrics_collection_interval = 60
          resources                   = ["*"]
        }
      }
    }
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Launch Template
# -----------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-${var.environment}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  vpc_security_group_ids = [var.security_group_id]

  key_name = var.key_name != "" ? var.key_name : null

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  # IMDSv2 required
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    app_port              = var.app_port
    node_env              = var.environment == "production" ? "production" : "development"
    app_s3_bucket         = var.app_s3_bucket
    cw_agent_config_param = "/${var.project}/${var.environment}/cloudwatch-agent/config"
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.project}-${var.environment}-app"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.tags, {
      Name = "${var.project}-${var.environment}-app-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-lt"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Group
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name                = "${var.project}-${var.environment}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_cooldown          = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-app"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# -----------------------------------------------------------------------------
# Scaling Policies
# -----------------------------------------------------------------------------

# Target Tracking — CPU Utilization
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project}-${var.environment}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.cpu_target
    disable_scale_in = false
  }
}

# Target Tracking — ALB Request Count per Target
resource "aws_autoscaling_policy" "request_count_tracking" {
  name                   = "${var.project}-${var.environment}-request-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_target_group_resource_label
    }
    target_value = 1000
  }
}

# Scheduled Scaling — Scale Up (weekday mornings)
resource "aws_autoscaling_schedule" "scale_up" {
  count = var.enable_scheduled_scaling ? 1 : 0

  scheduled_action_name  = "${var.project}-${var.environment}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  desired_capacity       = 4
  min_size               = 2
  max_size               = var.max_size
  recurrence             = "0 8 * * MON-FRI"
  time_zone              = "UTC"
}

# Scheduled Scaling — Scale Down (weekday evenings)
resource "aws_autoscaling_schedule" "scale_down" {
  count = var.enable_scheduled_scaling ? 1 : 0

  scheduled_action_name  = "${var.project}-${var.environment}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  desired_capacity       = 2
  min_size               = var.min_size
  max_size               = var.max_size
  recurrence             = "0 20 * * MON-FRI"
  time_zone              = "UTC"
}
