variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "account_id" {
  description = "AWS account ID — passed from root data source"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation or username for OIDC trust"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
