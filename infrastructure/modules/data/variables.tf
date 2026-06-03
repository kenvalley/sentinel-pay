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

variable "payments_task_role_arn" {
  description = "ARN of the payments-api ECS task role"
  type        = string
}

variable "kyc_task_role_arn" {
  description = "ARN of the kyc-api ECS task role"
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
