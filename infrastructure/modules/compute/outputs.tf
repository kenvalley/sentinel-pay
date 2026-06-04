# modules/compute/outputs.tf

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "payments_api_ecr_url" {
  description = "ECR repository URL for payments-api"
  value       = aws_ecr_repository.payments_api.repository_url
}

output "kyc_api_ecr_url" {
  description = "ECR repository URL for kyc-api"
  value       = aws_ecr_repository.kyc_api.repository_url
}

output "payments_api_service_name" {
  description = "Name of the payments-api ECS service"
  value       = aws_ecs_service.payments_api.name
}

output "kyc_api_service_name" {
  description = "Name of the kyc-api ECS service"
  value       = aws_ecs_service.kyc_api.name
}
