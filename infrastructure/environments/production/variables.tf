# ── Project globals ───────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name used in resource naming and tagging"
  type        = string
  default     = "sentinelpay"
}

variable "environment" {
  description = "Deployment environment (production / staging)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging"], var.environment)
    error_message = "environment must be 'production' or 'staging'."
  }
}

variable "owner" {
  description = "Owning team — used in resource tags"
  type        = string
  default     = "platform"
}

# ── Network ───────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to deploy into — minimum 2"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB only)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets (ECS tasks)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets (RDS, ElastiCache)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

# ── Identity ──────────────────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub organisation or username for OIDC trust"
  type        = string
  # Set in terraform.tfvars — e.g. "kenvalley"
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust"
  type        = string
  # Set in terraform.tfvars — e.g. "sentinel-pay"
}

# ── Data ──────────────────────────────────────────────────────────────────────

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

# ── Compute ───────────────────────────────────────────────────────────────────

variable "payments_api_image" {
  description = "ECR image URI for payments-api (set after first image push)"
  type        = string
  default     = ""
}

variable "kyc_api_image" {
  description = "ECR image URI for kyc-api (set after first image push)"
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
  description = "CPU units for each ECS task (1024 = 1 vCPU)"
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

# ── Edge ──────────────────────────────────────────────────────────────────────

variable "waf_rate_limit" {
  description = "Max requests per 5-minute window per IP on the payments path"
  type        = number
  default     = 100
}

# ── Observability ─────────────────────────────────────────────────────────────

variable "cloudtrail_retention_days" {
  description = "CloudWatch log group retention for CloudTrail (days)"
  type        = number
  default     = 90
}

variable "flow_log_retention_days" {
  description = "CloudWatch log group retention for VPC flow logs (days)"
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email address for security alarm notifications"
  type        = string
  # Set in terraform.tfvars
}
