output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "flow_log_group_arn" {
  description = "ARN of the VPC flow logs CloudWatch log group"
  value       = aws_cloudwatch_log_group.flow_logs.arn
}

output "flow_log_role_arn" {
  description = "ARN of the IAM role for VPC flow logs"
  value       = aws_iam_role.flow_logs.arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.main.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "app_log_group_name" {
  description = "Name of the app log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "syslog_group_name" {
  description = "Name of the syslog log group"
  value       = aws_cloudwatch_log_group.syslog.name
}
