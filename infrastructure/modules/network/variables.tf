variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs to deploy into"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets"
  type        = list(string)
}

variable "flow_log_retention_days" {
  description = "Retention period for VPC flow logs in CloudWatch (days)"
  type        = number
  default     = 30
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

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
