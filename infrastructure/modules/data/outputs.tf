# ── KMS Key ARNs ──────────────────────────────────────────────────────────────

output "rds_kms_key_arn" {
  description = "ARN of the RDS KMS key"
  value       = aws_kms_key.rds.arn
}

output "s3_kyc_kms_key_arn" {
  description = "ARN of the S3 KYC KMS key"
  value       = aws_kms_key.s3_kyc.arn
}

output "audit_kms_key_arn" {
  description = "ARN of the audit S3 and CloudTrail KMS key"
  value       = aws_kms_key.s3_audit.arn
}

output "elasticache_kms_key_arn" {
  description = "ARN of the ElastiCache KMS key"
  value       = aws_kms_key.elasticache.arn
}

# ── RDS ───────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "RDS instance endpoint (private)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "PostgreSQL database name"
  value       = aws_db_instance.main.db_name
}

# ── Secrets Manager ARNs ──────────────────────────────────────────────────────

output "db_secret_arn" {
  description = "ARN of the DB master password secret"
  value       = aws_secretsmanager_secret.db_master_password.arn
}

output "redis_auth_secret_arn" {
  description = "ARN of the Redis AUTH token secret"
  value       = aws_secretsmanager_secret.redis_auth.arn
}

output "jwt_private_key_secret_arn" {
  description = "ARN of the JWT private key secret"
  value       = aws_secretsmanager_secret.jwt_private_key.arn
}

output "jwt_public_key_secret_arn" {
  description = "ARN of the JWT public key secret"
  value       = aws_secretsmanager_secret.jwt_public_key.arn
}

# ── S3 Buckets ────────────────────────────────────────────────────────────────

output "kyc_bucket_name" {
  description = "S3 bucket name for KYC documents"
  value       = aws_s3_bucket.kyc_documents.bucket
}

output "kyc_bucket_arn" {
  description = "S3 bucket ARN for KYC documents"
  value       = aws_s3_bucket.kyc_documents.arn
}

output "audit_bucket_name" {
  description = "S3 bucket name for audit logs"
  value       = aws_s3_bucket.audit.bucket
}

output "audit_bucket_arn" {
  description = "S3 bucket ARN for audit logs"
  value       = aws_s3_bucket.audit.arn
}

# ── ElastiCache ───────────────────────────────────────────────────────────────

output "redis_primary_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}
