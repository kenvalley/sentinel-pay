# infrastructure/modules/data/variables.tf

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

variable "private_data_subnet_ids" {
  description = "IDs of private data subnets for RDS and ElastiCache"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "elasticache_sg_id" {
  description = "Security group ID for ElastiCache"
  type        = string
}

# ── Execution roles — used in KMS key policies ────────────────────────────────
# The EXECUTION ROLE is what decrypts secrets at container startup.
# These replace the old payments_task_role_arn / kyc_task_role_arn in KMS policies.

variable "payments_execution_role_arn" {
  description = "ARN of the payments-api ECS execution role — used in KMS key policies for secret decryption"
  type        = string
}

variable "kyc_execution_role_arn" {
  description = "ARN of the kyc-api ECS execution role — used in KMS key policies for secret decryption"
  type        = string
}

# ── Task roles — used in S3 bucket policies ───────────────────────────────────
# The TASK ROLE is what the application code uses at runtime.
# Still needed for the KYC S3 bucket policy.

variable "kyc_task_role_arn" {
  description = "ARN of the kyc-api ECS task role — used in S3 bucket policy for runtime access"
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "sentinelpay"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "sentinel"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
