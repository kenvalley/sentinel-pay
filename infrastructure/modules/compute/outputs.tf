output "payments_api_ecr_url" {
  description = "ECR repository URL for payments-api"
  value       = aws_ecr_repository.payments_api.repository_url
}

output "kyc_api_ecr_url" {
  description = "ECR repository URL for kyc-api"
  value       = aws_ecr_repository.kyc_api.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "payments_api_service_name" {
  description = "ECS service name for payments-api"
  value       = aws_ecs_service.payments_api.name
}

output "kyc_api_service_name" {
  description = "ECS service name for kyc-api"
  value       = aws_ecs_service.kyc_api.name
}

output "payments_api_log_group" {
  description = "CloudWatch log group for payments-api"
  value       = aws_cloudwatch_log_group.payments_api.name
}

output "kyc_api_log_group" {
  description = "CloudWatch log group for kyc-api"
  value       = aws_cloudwatch_log_group.kyc_api.name
}
