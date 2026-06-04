# modules/compute/variables.tf

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
}

# ── IAM Roles — SEPARATE execution and task roles ─────────────────────────────

variable "payments_api_execution_role_arn" {
  description = "ARN of the payments-api ECS execution role (used by ECS agent — pulls secrets and images)"
  type        = string
}

variable "payments_api_task_role_arn" {
  description = "ARN of the payments-api ECS task role (used by application code at runtime)"
  type        = string
}

variable "kyc_api_execution_role_arn" {
  description = "ARN of the kyc-api ECS execution role (used by ECS agent — pulls secrets and images)"
  type        = string
}

variable "kyc_api_task_role_arn" {
  description = "ARN of the kyc-api ECS task role (used by application code at runtime)"
  type        = string
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "private_app_subnet_ids" {
  description = "Private app subnet IDs for ECS tasks"
  type        = list(string)
}

variable "payments_api_sg_id" {
  description = "Security group ID for payments-api tasks"
  type        = string
}

variable "kyc_api_sg_id" {
  description = "Security group ID for kyc-api tasks"
  type        = string
}

# ── ALB Target Groups ─────────────────────────────────────────────────────────

variable "alb_target_group_payments" {
  description = "ARN of the ALB target group for payments-api"
  type        = string
}

variable "alb_target_group_kyc" {
  description = "ARN of the ALB target group for kyc-api"
  type        = string
}

# ── Secrets ───────────────────────────────────────────────────────────────────

variable "db_secret_arn" {
  description = "ARN of the database password secret in Secrets Manager"
  type        = string
}

variable "redis_auth_secret_arn" {
  description = "ARN of the Redis AUTH token secret in Secrets Manager"
  type        = string
}

variable "jwt_private_key_secret_arn" {
  description = "ARN of the JWT private key secret in Secrets Manager"
  type        = string
}

variable "jwt_public_key_secret_arn" {
  description = "ARN of the JWT public key secret in Secrets Manager"
  type        = string
}

# ── Application Config ────────────────────────────────────────────────────────

variable "kyc_bucket_name" {
  description = "Name of the KYC documents S3 bucket (plain string, not a secret)"
  type        = string
}

variable "payments_api_image" {
  description = "Docker image URI for payments-api (leave empty to use ECR latest)"
  type        = string
  default     = ""
}

variable "kyc_api_image" {
  description = "Docker image URI for kyc-api (leave empty to use ECR latest)"
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
  description = "CPU units for ECS tasks"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory (MiB) for ECS tasks"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks per service"
  type        = number
  default     = 2
}
