output "alb_sg_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "ec2_sg_id" {
  description = "Security group ID for EC2 instances"
  value       = aws_security_group.ec2.id
}

output "db_sg_id" {
  description = "Security group ID for database tier"
  value       = aws_security_group.db.id
}

output "iam_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2.name
}

output "iam_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.main.key_id
}
