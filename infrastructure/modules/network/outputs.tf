output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (ALB)"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of private application subnets (ECS tasks)"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs of private data subnets (RDS, ElastiCache)"
  value       = aws_subnet.private_data[*].id
}

output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "payments_api_sg_id" {
  description = "Security group ID for payments-api ECS tasks"
  value       = aws_security_group.payments_api.id
}

output "kyc_api_sg_id" {
  description = "Security group ID for kyc-api ECS tasks"
  value       = aws_security_group.kyc_api.id
}

output "rds_sg_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "elasticache_sg_id" {
  description = "Security group ID for ElastiCache"
  value       = aws_security_group.elasticache.id
}
