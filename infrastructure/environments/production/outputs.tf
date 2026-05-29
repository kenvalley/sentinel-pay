# ── Root outputs ──────────────────────────────────────────────────────────────
# Populated progressively as modules are added across Days 9-12.
# Placeholders marked with comments will be uncommented on the relevant day.

# ── Day 9 outputs (to be uncommented after applying network + identity modules) ───────

# output "vpc_id" {
#   description = "VPC ID"
#   value       = module.network.vpc_id
# }

# output "payments_api_task_role_arn" {
#   description = "IAM role ARN for payments-api ECS tasks"
#   value       = module.identity.payments_api_task_role_arn
# }

# output "kyc_api_task_role_arn" {
#   description = "IAM role ARN for kyc-api ECS tasks"
#   value       = module.identity.kyc_api_task_role_arn
# }

# ── Day 10 outputs (to be uncommented after applying data module) ─────────────────────

# output "rds_endpoint" {
#   description = "RDS instance endpoint (private)"
#   value       = module.data.rds_endpoint
#   sensitive   = true
# }

# output "kyc_bucket_name" {
#   description = "S3 bucket name for KYC documents"
#   value       = module.data.kyc_bucket_name
# }

# ── Day 11 outputs (to be uncommented after applying compute + edge modules) ──────────

# output "alb_dns_name" {
#   description = "ALB DNS name — use this to reach the API"
#   value       = module.edge.alb_dns_name
# }

# output "payments_api_ecr_url" {
#   description = "ECR repository URL for payments-api"
#   value       = module.compute.payments_api_ecr_url
# }

# output "kyc_api_ecr_url" {
#   description = "ECR repository URL for kyc-api"
#   value       = module.compute.kyc_api_ecr_url
# }

# ── Day 12 outputs (to be uncommented after applying observability module) ─────────────

# output "guardduty_detector_id" {
#   description = "GuardDuty detector ID"
#   value       = module.observability.guardduty_detector_id
# }

# output "cloudtrail_arn" {
#   description = "CloudTrail trail ARN"
#   value       = module.observability.cloudtrail_arn
# }
