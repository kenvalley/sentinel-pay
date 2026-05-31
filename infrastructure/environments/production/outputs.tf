# ── Day 9 outputs ─────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "payments_api_task_role_arn" {
  description = "IAM role ARN for payments-api ECS tasks"
  value       = module.identity.payments_api_task_role_arn
}

output "kyc_api_task_role_arn" {
  description = "IAM role ARN for kyc-api ECS tasks"
  value       = module.identity.kyc_api_task_role_arn
}

output "github_actions_deploy_role_arn" {
  description = "GitHub Actions deployment role ARN - add to repo secrets as AWS_ROLE_ARN"
  value       = module.identity.github_actions_deploy_role_arn
}

# ── Day 10 outputs ────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "RDS instance endpoint (private)"
  value       = module.data.rds_endpoint
  sensitive   = true
}

output "kyc_bucket_name" {
  description = "S3 bucket name for KYC documents"
  value       = module.data.kyc_bucket_name
}

output "audit_bucket_name" {
  description = "S3 bucket name for audit logs"
  value       = module.data.audit_bucket_name
}

output "db_secret_arn" {
  description = "ARN of the DB master password secret"
  value       = module.data.db_secret_arn
}

# ── Day 11 outputs ────────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "ALB DNS name - use this to reach the API"
  value       = module.edge.alb_dns_name
}

output "payments_api_ecr_url" {
  description = "ECR repository URL for payments-api"
  value       = module.compute.payments_api_ecr_url
}

output "kyc_api_ecr_url" {
  description = "ECR repository URL for kyc-api"
  value       = module.compute.kyc_api_ecr_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.compute.ecs_cluster_name
}

# ── Day 12 outputs (uncomment after applying observability module) ─────────────

# output "guardduty_detector_id" {
#   description = "GuardDuty detector ID"
#   value       = module.observability.guardduty_detector_id
# }

# output "cloudtrail_arn" {
#   description = "CloudTrail trail ARN"
#   value       = module.observability.cloudtrail_arn
# }

# ── Day 12 outputs ────────────────────────────────────────────────────────────

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.observability.guardduty_detector_id
}

output "cloudtrail_arn" {
  description = "CloudTrail trail ARN"
  value       = module.observability.cloudtrail_arn
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for security alerts"
  value       = module.observability.security_alerts_topic_arn
}

output "containment_lambda_arn" {
  description = "Containment Lambda ARN"
  value       = module.observability.containment_lambda_arn
}
