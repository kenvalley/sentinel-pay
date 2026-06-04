# modules/identity/outputs.tf

output "payments_api_task_role_arn" {
  description = "ARN of the payments-api ECS task role (used by application code)"
  value       = aws_iam_role.payments_api_task.arn
}

output "payments_api_execution_role_arn" {
  description = "ARN of the payments-api ECS execution role (used by ECS agent to pull secrets/images)"
  value       = aws_iam_role.payments_api_execution.arn
}

output "kyc_api_task_role_arn" {
  description = "ARN of the kyc-api ECS task role (used by application code)"
  value       = aws_iam_role.kyc_api_task.arn
}

output "kyc_api_execution_role_arn" {
  description = "ARN of the kyc-api ECS execution role (used by ECS agent to pull secrets/images)"
  value       = aws_iam_role.kyc_api_execution.arn
}

output "github_actions_deploy_role_arn" {
  description = "ARN of the GitHub Actions deployment role (OIDC)"
  value       = aws_iam_role.github_actions_deploy.arn
}
