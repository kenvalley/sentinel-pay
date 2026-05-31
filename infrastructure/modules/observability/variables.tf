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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "audit_bucket_name" {
  description = "S3 audit bucket name for CloudTrail logs"
  type        = string
}

variable "audit_kms_key_arn" {
  description = "KMS key ARN for audit log encryption"
  type        = string
}

variable "cloudtrail_retention_days" {
  description = "CloudWatch log retention for CloudTrail (days)"
  type        = number
  default     = 90
}

variable "alarm_email" {
  description = "Email address for security alarm notifications"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
