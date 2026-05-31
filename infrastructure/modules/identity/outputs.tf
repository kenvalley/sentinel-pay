output "payments_api_task_role_arn" {
  description = "ARN of the payments-api ECS task role"
  value       = aws_iam_role.payments_api_task.arn
}

output "payments_api_task_role_name" {
  description = "Name of the payments-api ECS task role"
  value       = aws_iam_role.payments_api_task.name
}

output "kyc_api_task_role_arn" {
  description = "ARN of the kyc-api ECS task role"
  value       = aws_iam_role.kyc_api_task.arn
}

output "kyc_api_task_role_name" {
  description = "Name of the kyc-api ECS task role"
  value       = aws_iam_role.kyc_api_task.name
}

output "github_actions_deploy_role_arn" {
  description = "ARN of the GitHub Actions deployment role — used in OIDC trust"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
