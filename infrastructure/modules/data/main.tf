# infrastructure/modules/data/main.tf
#
# Fix: KMS key policies now reference execution roles (not task roles)
# because it is the EXECUTION ROLE that decrypts secrets at container startup.
# The task role is used by application code at runtime and does not need KMS access
# for secrets injection.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── KMS Keys ──────────────────────────────────────────────────────────────────

resource "aws_kms_key" "rds" {
  description             = "CMK for RDS encryption - ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRDSServiceUse"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        # Execution role decrypts secrets at container startup
        Sid    = "AllowExecutionRoleDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = var.payments_execution_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-rds-key"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_key" "s3_kyc" {
  description             = "CMK for S3 KYC documents - ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3ServiceUse"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        # kyc-api task role needs KMS access for S3 operations at runtime
        Sid    = "AllowKYCTaskRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.kyc_task_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-s3-kyc-key"
  })
}

resource "aws_kms_alias" "s3_kyc" {
  name          = "alias/${var.name_prefix}-s3-kyc"
  target_key_id = aws_kms_key.s3_kyc.key_id
}

resource "aws_kms_key" "s3_audit" {
  description             = "CMK for S3 audit logs and CloudTrail - ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3ServiceUse"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        # Both execution roles need to decrypt secrets stored with this key
        Sid    = "AllowExecutionRolesDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = [
            var.payments_execution_role_arn,
            var.kyc_execution_role_arn
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-s3-audit-key"
  })
}

resource "aws_kms_alias" "s3_audit" {
  name          = "alias/${var.name_prefix}-s3-audit"
  target_key_id = aws_kms_key.s3_audit.key_id
}

resource "aws_kms_key" "elasticache" {
  description             = "CMK for ElastiCache Redis - ${var.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        # Execution roles decrypt Redis auth token at container startup
        Sid    = "AllowExecutionRolesDecrypt"
        Effect = "Allow"
        Principal = {
          AWS = [
            var.payments_execution_role_arn,
            var.kyc_execution_role_arn
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-elasticache-key"
  })
}

resource "aws_kms_alias" "elasticache" {
  name          = "alias/${var.name_prefix}-elasticache"
  target_key_id = aws_kms_key.elasticache.key_id
}

# ── Secrets Manager ───────────────────────────────────────────────────────────

resource "random_password" "db_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_master_password" {
  name                    = "${var.name_prefix}/payments-api/db-master-password"
  description             = "RDS master password for ${var.name_prefix}"
  kms_key_id              = aws_kms_key.s3_audit.arn
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-master-password"
  })
}

resource "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = aws_secretsmanager_secret.db_master_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
  })
}

resource "random_password" "redis_auth" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${var.name_prefix}/payments-api/redis-auth-token"
  description             = "ElastiCache Redis AUTH token for ${var.name_prefix}"
  kms_key_id              = aws_kms_key.s3_audit.arn
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis-auth-token"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result
}

resource "aws_secretsmanager_secret" "jwt_private_key" {
  name                    = "${var.name_prefix}/payments-api/jwt-private-key"
  description             = "RS256 JWT private key for ${var.name_prefix}"
  kms_key_id              = aws_kms_key.s3_audit.arn
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-jwt-private-key"
  })
}

resource "aws_secretsmanager_secret" "jwt_public_key" {
  name                    = "${var.name_prefix}/payments-api/jwt-public-key"
  description             = "RS256 JWT public key for ${var.name_prefix}"
  kms_key_id              = aws_kms_key.s3_audit.arn
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-jwt-public-key"
  })
}

# ── RDS ───────────────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "RDS subnet group - private data subnets only"
  subnet_ids  = var.private_data_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

resource "aws_db_parameter_group" "main" {
  name        = "${var.name_prefix}-pg15"
  family      = "postgres15"
  description = "SentinelPay PostgreSQL 15 parameter group"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = var.common_tags
}

resource "aws_db_instance" "main" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = "15"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false

  multi_az = true

  backup_retention_period = 7
  backup_window           = "02:00-03:00"
  maintenance_window      = "Mon:03:00-Mon:04:00"

  deletion_protection       = true
  skip_final_snapshot       = true
  copy_tags_to_snapshot     = true

  parameter_group_name = aws_db_parameter_group.main.name

  performance_insights_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-postgres"
  })
}

# ── ElastiCache ───────────────────────────────────────────────────────────────

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.name_prefix}-redis-subnet-group"
  description = "ElastiCache subnet group - private data subnets only"
  subnet_ids  = var.private_data_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis-subnet-group"
  })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "SentinelPay Redis cache - encrypted in transit and at rest"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.redis_node_type
  num_cache_clusters   = 2
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.elasticache_sg_id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.elasticache.arn
  auth_token                 = random_password.redis_auth.result

  snapshot_retention_limit   = 1
  snapshot_window            = "03:00-04:00"
  auto_minor_version_upgrade = true
  automatic_failover_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis"
  })
}

# ── S3 Audit Bucket ───────────────────────────────────────────────────────────

resource "aws_s3_bucket" "audit" {
  bucket        = "${var.name_prefix}-audit-logs-2"
  force_destroy = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-audit-logs-2"
  })
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_audit.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 365
    }
  }
  depends_on = [aws_s3_bucket_versioning.audit]
}

resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    filter {}
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_policy" "audit_alb" {
  bucket = aws_s3_bucket.audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBAccessLogs"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::652711504416:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit.arn}/alb-access-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid    = "AllowCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AllowCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit.arn
      },
      {
        Sid    = "DenyNonSSLAccess"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.audit.arn,
          "${aws_s3_bucket.audit.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_versioning.audit]
}

# ── S3 KYC Documents Bucket ───────────────────────────────────────────────────

resource "aws_s3_bucket" "kyc_documents" {
  bucket        = "${var.name_prefix}-kyc-documents"
  force_destroy = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-kyc-documents"
  })
}

resource "aws_s3_bucket_versioning" "kyc_documents" {
  bucket = aws_s3_bucket.kyc_documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kyc_documents" {
  bucket = aws_s3_bucket.kyc_documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kyc.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "kyc_documents" {
  bucket                  = aws_s3_bucket.kyc_documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "kyc_documents" {
  bucket = aws_s3_bucket.kyc_documents.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }
  depends_on = [aws_s3_bucket_versioning.kyc_documents]
}

resource "aws_s3_bucket_logging" "kyc_documents" {
  bucket        = aws_s3_bucket.kyc_documents.id
  target_bucket = aws_s3_bucket.audit.id
  target_prefix = "s3-access-logs/kyc-documents/"
}

resource "aws_s3_bucket_policy" "kyc_documents" {
  bucket = aws_s3_bucket.kyc_documents.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonSSLAccess"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.kyc_documents.arn,
          "${aws_s3_bucket.kyc_documents.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        # kyc-api task role accesses S3 at runtime
        Sid    = "AllowKYCTaskRoleOnly"
        Effect = "Allow"
        Principal = {
          AWS = var.kyc_task_role_arn
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.kyc_documents.arn,
          "${aws_s3_bucket.kyc_documents.arn}/*"
        ]
      }
    ]
  })
}
