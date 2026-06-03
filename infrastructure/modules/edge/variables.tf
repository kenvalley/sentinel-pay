variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for the ALB"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB"
  type        = string
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

variable "waf_rate_limit" {
  description = "Max requests per 5-minute window per IP on the payments path"
  type        = number
  default     = 100
}

variable "audit_bucket_name" {
  description = "S3 audit bucket name for ALB access logs"
  type        = string
}

variable "audit_bucket_arn" {
  description = "S3 audit bucket ARN for WAF logging"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
