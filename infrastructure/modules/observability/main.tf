# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── GuardDuty — closes V-CLD-07 ───────────────────────────────────────────────

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-guardduty"
  })
}

# ── CloudTrail — closes V-CLD-06 ──────────────────────────────────────────────
# CloudWatch log group without KMS to avoid key policy complexity.
# CloudTrail itself is KMS encrypted at the S3 level.

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.cloudtrail_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-cloudtrail-logs"
  })
}

resource "aws_iam_role" "cloudtrail" {
  name = "${var.name_prefix}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "cloudtrail" {
  name = "${var.name_prefix}-cloudtrail-policy"
  role = aws_iam_role.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = var.audit_bucket_name
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.audit_kms_key_arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${var.audit_bucket_name}/"]
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-trail"
  })

  depends_on = [aws_iam_role_policy.cloudtrail]
}

# ── Security Hub ──────────────────────────────────────────────────────────────

resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# CIS v1.4.0 — v1.2.0 is no longer available in eu-west-2
resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.main]
}

# ── S3 bucket for AWS Config ──────────────────────────────────────────────────
# Separate bucket without Object Lock — Config requires PutObject without
# Object Lock retention constraints.

resource "aws_s3_bucket" "config" {
  bucket        = "${var.name_prefix}-config-logs"
  force_destroy = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-config-logs"
  })
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowConfigWrite"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = ["s3:PutObject", "s3:GetBucketAcl"]
        Resource = [
          aws_s3_bucket.config.arn,
          "${aws_s3_bucket.config.arn}/*"
        ]
      },
      {
        Sid    = "DenyNonSSL"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          aws_s3_bucket.config.arn,
          "${aws_s3_bucket.config.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_versioning.config]
}

# ── AWS Config ────────────────────────────────────────────────────────────────

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config" {
  name = "${var.name_prefix}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.name_prefix}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config.bucket
  s3_key_prefix  = "aws-config"

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [
    aws_config_configuration_recorder.main,
    aws_s3_bucket_policy.config
  ]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# CIS conformance pack
resource "aws_config_conformance_pack" "cis" {
  name = "${var.name_prefix}-cis-conformance"

  template_body = <<-EOT
    Parameters:
      AccessKeysRotatedParamMaxAccessKeyAge:
        Default: '90'
        Type: String
    Resources:
      AccessKeysRotated:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: access-keys-rotated
          Source:
            Owner: AWS
            SourceIdentifier: ACCESS_KEYS_ROTATED
          InputParameters:
            maxAccessKeyAge: !Ref AccessKeysRotatedParamMaxAccessKeyAge
      RootAccountMFAEnabled:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: root-account-mfa-enabled
          Source:
            Owner: AWS
            SourceIdentifier: ROOT_ACCOUNT_MFA_ENABLED
      IAMPasswordPolicy:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: iam-password-policy
          Source:
            Owner: AWS
            SourceIdentifier: IAM_PASSWORD_POLICY
      S3BucketPublicReadProhibited:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: s3-bucket-public-read-prohibited
          Source:
            Owner: AWS
            SourceIdentifier: S3_BUCKET_PUBLIC_READ_PROHIBITED
      RestrictedSSH:
        Type: AWS::Config::ConfigRule
        Properties:
          ConfigRuleName: restricted-ssh
          Source:
            Owner: AWS
            SourceIdentifier: INCOMING_SSH_DISABLED
  EOT

  depends_on = [aws_config_configuration_recorder_status.main]
}

# ── SNS Topic for Alerts ──────────────────────────────────────────────────────

resource "aws_sns_topic" "security_alerts" {
  name              = "${var.name_prefix}-security-alerts"
  kms_master_key_id = var.audit_kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-security-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ── Lambda Containment Function ───────────────────────────────────────────────

resource "aws_iam_role" "containment_lambda" {
  name = "${var.name_prefix}-containment-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "containment_lambda" {
  name = "${var.name_prefix}-containment-lambda-policy"
  role = aws_iam_role.containment_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMContainment"
        Effect = "Allow"
        Action = [
          "iam:AttachUserPolicy",
          "iam:AttachRolePolicy",
          "iam:PutUserPolicy",
          "iam:PutRolePolicy",
          "iam:GetUser",
          "iam:GetRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

data "archive_file" "containment_lambda" {
  type        = "zip"
  output_path = "/tmp/containment_lambda.zip"

  source {
    content  = <<-EOT
      import boto3
      import json
      import os

      iam = boto3.client('iam')
      sns = boto3.client('sns')

      DENY_ALL_POLICY = json.dumps({
          "Version": "2012-10-17",
          "Statement": [{
              "Effect": "Deny",
              "Action": "*",
              "Resource": "*"
          }]
      })

      def handler(event, context):
          print(f"Containment triggered: {json.dumps(event)}")
          finding = event.get('detail', {})
          severity = finding.get('severity', 0)
          finding_type = finding.get('type', 'Unknown')
          principal = None
          resource = finding.get('resource', {})
          if 'accessKeyDetails' in resource:
              principal = resource['accessKeyDetails'].get('userName')
              if principal:
                  try:
                      iam.put_user_policy(
                          UserName=principal,
                          PolicyName='EmergencyDenyAll',
                          PolicyDocument=DENY_ALL_POLICY
                      )
                      print(f"Attached deny-all policy to user: {principal}")
                  except Exception as e:
                      print(f"Failed to contain user {principal}: {e}")
          message = {
              "alert": "P0 - GuardDuty High Severity Finding",
              "finding_type": finding_type,
              "severity": severity,
              "principal_contained": principal,
              "finding": finding
          }
          sns.publish(
              TopicArn=os.environ['SNS_TOPIC_ARN'],
              Subject=f"P0 SECURITY ALERT: {finding_type}",
              Message=json.dumps(message, indent=2)
          )
          return {"status": "contained", "principal": principal}
    EOT
    filename = "index.py"
  }
}

resource "aws_lambda_function" "containment" {
  filename         = data.archive_file.containment_lambda.output_path
  function_name    = "${var.name_prefix}-containment"
  role             = aws_iam_role.containment_lambda.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.containment_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-containment-lambda"
  })
}

# ── EventBridge — GuardDuty HIGH findings ────────────────────────────────────

resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${var.name_prefix}-guardduty-high"
  description = "Route GuardDuty HIGH severity findings to containment Lambda"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-guardduty-high-rule"
  })
}

resource "aws_cloudwatch_event_target" "guardduty_high" {
  rule      = aws_cloudwatch_event_rule.guardduty_high.name
  target_id = "ContainmentLambda"
  arn       = aws_lambda_function.containment.arn
}

resource "aws_lambda_permission" "guardduty_high" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.containment.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_high.arn
}

# ── Honeytoken ────────────────────────────────────────────────────────────────

resource "aws_iam_user" "honeytoken" {
  name = "${var.name_prefix}-honeytoken-user"
  path = "/sentinelpay/decoy/"

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-honeytoken"
    Purpose = "Tripwire - alert on any use of this identity"
  })
}

resource "aws_iam_user_policy" "honeytoken" {
  name = "${var.name_prefix}-honeytoken-deny-all"
  user = aws_iam_user.honeytoken.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_access_key" "honeytoken" {
  user = aws_iam_user.honeytoken.name
}

resource "aws_secretsmanager_secret" "honeytoken" {
  name                    = "${var.name_prefix}/decoy/legacy-credentials"
  description             = "Honeytoken - decoy credentials. Any use triggers P0 alert."
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name    = "${var.name_prefix}-honeytoken-secret"
    Purpose = "Tripwire"
  })
}

resource "aws_secretsmanager_secret_version" "honeytoken" {
  secret_id = aws_secretsmanager_secret.honeytoken.id
  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.honeytoken.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.honeytoken.secret
    Note                  = "Legacy credentials - DO NOT USE"
  })
}

resource "aws_cloudwatch_metric_alarm" "honeytoken_used" {
  alarm_name          = "${var.name_prefix}-honeytoken-used"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HoneytokenUsed"
  namespace           = "SentinelPay/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "P0: Honeytoken credentials used - likely credential theft"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-honeytoken-alarm"
  })
}

resource "aws_cloudwatch_event_rule" "honeytoken_used" {
  name        = "${var.name_prefix}-honeytoken-used"
  description = "Detect any API call using the honeytoken access key"

  event_pattern = jsonencode({
    source      = ["aws.sts", "aws.iam", "aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      userIdentity = {
        accessKeyId = [aws_iam_access_key.honeytoken.id]
      }
    }
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-honeytoken-event-rule"
  })
}

resource "aws_cloudwatch_event_target" "honeytoken_containment" {
  rule      = aws_cloudwatch_event_rule.honeytoken_used.name
  target_id = "HoneytokenContainment"
  arn       = aws_lambda_function.containment.arn
}

resource "aws_lambda_permission" "honeytoken_used" {
  statement_id  = "AllowHoneytokenEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.containment.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.honeytoken_used.arn
}

# ── Root account usage alarm ──────────────────────────────────────────────────

resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "${var.name_prefix}-root-usage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "SentinelPay/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "${var.name_prefix}-root-account-used"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "SentinelPay/Security"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Root account activity detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-root-usage-alarm"
  })
}
