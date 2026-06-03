variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "IDs of private application subnets for ECS tasks"
  type        = list(string)
}

variable "payments_api_sg_id" {
  description = "Security group ID for payments-api ECS tasks"
  type        = string
}

variable "kyc_api_sg_id" {
  description = "Security group ID for kyc-api ECS tasks"
  type        = string
}

variable "payments_api_task_role_arn" {
  description = "ARN of the payments-api ECS task role"
  type        = string
}

variable "kyc_api_task_role_arn" {
  description = "ARN of the kyc-api ECS task role"
  type        = string
}

variable "alb_target_group_payments" {
  description = "ALB target group ARN for payments-api"
  type        = string
}

variable "alb_target_group_kyc" {
  description = "ALB target group ARN for kyc-api"
  type        = string
}

variable "payments_api_image" {
  description = "ECR image URI for payments-api"
  type        = string
  default     = ""
}

variable "kyc_api_image" {
  description = "ECR image URI for kyc-api"
  type        = string
  default     = ""
}

variable "payments_api_port" {
  description = "Container port for payments-api"
  type        = number
  default     = 8001
}

variable "kyc_api_port" {
  description = "Container port for kyc-api"
  type        = number
  default     = 8002
}

variable "ecs_task_cpu" {
  description = "CPU units for each ECS task"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory in MiB for each ECS task"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks per service"
  type        = number
  default     = 2
}

variable "db_secret_arn" {
  description = "ARN of the DB master password secret"
  type        = string
}

variable "redis_auth_secret_arn" {
  description = "ARN of the Redis AUTH token secret"
  type        = string
}

variable "jwt_private_key_secret_arn" {
  description = "ARN of the JWT private key secret"
  type        = string
}

variable "jwt_public_key_secret_arn" {
  description = "ARN of the JWT public key secret"
  type        = string
}

variable "kyc_bucket_name" {
  description = "S3 KYC bucket name"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
