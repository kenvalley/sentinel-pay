# environments/production/main.tf
#
# Key fix: execution role ARNs are now wired separately from task role ARNs.
# identity module produces 4 role ARNs:
#   - payments_api_execution_role_arn  → passed to data (KMS) and compute (execution_role_arn)
#   - payments_api_task_role_arn       → passed to compute (task_role_arn)
#   - kyc_api_execution_role_arn       → passed to data (KMS) and compute (execution_role_arn)
#   - kyc_api_task_role_arn            → passed to data (S3 policy) and compute (task_role_arn)

# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── Local values ──────────────────────────────────────────────────────────────

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Owner       = var.owner
    Environment = var.environment
    Service     = var.project_name
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}

# ── Network ───────────────────────────────────────────────────────────────────

module "network" {
  source = "../../modules/network"

  name_prefix               = local.name_prefix
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  flow_log_retention_days   = var.flow_log_retention_days
  payments_api_port         = var.payments_api_port
  kyc_api_port              = var.kyc_api_port
  common_tags               = local.common_tags
}

# ── Identity ──────────────────────────────────────────────────────────────────
# Produces SEPARATE execution and task roles for each service.

module "identity" {
  source = "../../modules/identity"

  name_prefix = local.name_prefix
  account_id  = local.account_id
  github_org  = var.github_org
  github_repo = var.github_repo
  common_tags = local.common_tags
}

# ── Data ──────────────────────────────────────────────────────────────────────
# Execution roles go into KMS key policies (decrypt secrets at startup).
# kyc task role goes into S3 bucket policy (runtime S3 access).

module "data" {
  source = "../../modules/data"

  name_prefix             = local.name_prefix
  account_id              = local.account_id
  region                  = local.region
  private_data_subnet_ids = module.network.private_data_subnet_ids
  rds_sg_id               = module.network.rds_sg_id
  elasticache_sg_id       = module.network.elasticache_sg_id

  # Execution roles — used in KMS key policies for secret decryption at startup
  payments_execution_role_arn = module.identity.payments_api_execution_role_arn
  kyc_execution_role_arn      = module.identity.kyc_api_execution_role_arn

  # Task role — used in S3 bucket policy for runtime access
  kyc_task_role_arn = module.identity.kyc_api_task_role_arn

  db_name           = var.db_name
  db_username       = var.db_username
  db_instance_class = var.db_instance_class
  redis_node_type   = var.redis_node_type
  common_tags       = local.common_tags
}

# ── Edge ──────────────────────────────────────────────────────────────────────

module "edge" {
  source = "../../modules/edge"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  alb_sg_id         = module.network.alb_sg_id
  payments_api_port = var.payments_api_port
  kyc_api_port      = var.kyc_api_port
  waf_rate_limit    = var.waf_rate_limit
  audit_bucket_name = module.data.audit_bucket_name
  audit_bucket_arn  = module.data.audit_bucket_arn
  common_tags       = local.common_tags
}

# ── Compute ───────────────────────────────────────────────────────────────────
# CRITICAL: execution_role_arn and task_role_arn are now SEPARATE.
# execution_role = ECS agent uses to pull secrets/images before container starts
# task_role      = application code uses at runtime inside the container

module "compute" {
  source = "../../modules/compute"

  name_prefix = local.name_prefix

  # Separate execution and task roles — the root fix
  payments_api_execution_role_arn = module.identity.payments_api_execution_role_arn
  payments_api_task_role_arn      = module.identity.payments_api_task_role_arn
  kyc_api_execution_role_arn      = module.identity.kyc_api_execution_role_arn
  kyc_api_task_role_arn           = module.identity.kyc_api_task_role_arn

  private_app_subnet_ids    = module.network.private_app_subnet_ids
  payments_api_sg_id        = module.network.payments_api_sg_id
  kyc_api_sg_id             = module.network.kyc_api_sg_id
  alb_target_group_payments = module.edge.payments_target_group_arn
  alb_target_group_kyc      = module.edge.kyc_target_group_arn
  payments_api_image        = var.payments_api_image
  kyc_api_image             = var.kyc_api_image
  payments_api_port         = var.payments_api_port
  kyc_api_port              = var.kyc_api_port
  ecs_task_cpu              = var.ecs_task_cpu
  ecs_task_memory           = var.ecs_task_memory
  ecs_desired_count         = var.ecs_desired_count
  db_secret_arn             = module.data.db_secret_arn
  redis_auth_secret_arn     = module.data.redis_auth_secret_arn
  jwt_private_key_secret_arn = module.data.jwt_private_key_secret_arn
  jwt_public_key_secret_arn  = module.data.jwt_public_key_secret_arn
  kyc_bucket_name           = module.data.kyc_bucket_name
  common_tags               = local.common_tags
}

# ── Observability ─────────────────────────────────────────────────────────────

module "observability" {
  source = "../../modules/observability"

  name_prefix               = local.name_prefix
  account_id                = local.account_id
  region                    = local.region
  vpc_id                    = module.network.vpc_id
  audit_bucket_name         = module.data.audit_bucket_name
  audit_kms_key_arn         = module.data.audit_kms_key_arn
  cloudtrail_retention_days = var.cloudtrail_retention_days
  alarm_email               = var.alarm_email
  common_tags               = local.common_tags
}
