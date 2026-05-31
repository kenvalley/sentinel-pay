output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "cloudtrail_arn" {
  description = "CloudTrail trail ARN"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_log_group" {
  description = "CloudWatch log group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for security alerts"
  value       = aws_sns_topic.security_alerts.arn
}

output "containment_lambda_arn" {
  description = "ARN of the containment Lambda function"
  value       = aws_lambda_function.containment.arn
}

output "honeytoken_key_id" {
  description = "Access key ID of the honeytoken — embed in decoy file"
  value       = aws_iam_access_key.honeytoken.id
  sensitive   = true
}

output "honeytoken_secret_arn" {
  description = "Secrets Manager ARN for honeytoken credentials"
  value       = aws_secretsmanager_secret.honeytoken.arn
}
