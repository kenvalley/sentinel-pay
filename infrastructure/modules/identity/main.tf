# modules/identity/main.tf
#
# Key fix: Separate execution roles from task roles.
#
# execution_role  = used by the ECS AGENT before container starts
#                   needs: ECR pull, Secrets Manager read, CloudWatch logs
#
# task_role       = used by APPLICATION CODE inside the running container
#                   needs: only what the app calls at runtime (S3, etc.)
#
# Using the same role for both is the root cause of all secrets errors.

# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── payments-api Execution Role ───────────────────────────────────────────────
# Used by the ECS agent to pull secrets and images BEFORE container starts.

resource "aws_iam_role" "payments_api_execution" {
  name        = "${var.name_prefix}-payments-api-execution-role"
  description = "ECS execution role for payments-api - pulls secrets and images"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "payments_api_execution_managed" {
  role       = aws_iam_role.payments_api_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "payments_api_execution_secrets" {
  name = "${var.name_prefix}-payments-api-execution-secrets"
  role = aws_iam_role.payments_api_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/payments-api/*"
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ── payments-api Task Role ────────────────────────────────────────────────────
# Used by APPLICATION CODE inside the running container.

resource "aws_iam_role" "payments_api_task" {
  name        = "${var.name_prefix}-payments-api-task-role"
  description = "ECS task role for payments-api - least privilege runtime permissions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "payments_api_task" {
  name = "${var.name_prefix}-payments-api-task-policy"
  role = aws_iam_role.payments_api_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.name_prefix}/payments-api:*"
      }
    ]
  })
}

# ── kyc-api Execution Role ────────────────────────────────────────────────────
# Used by the ECS agent to pull secrets and images BEFORE container starts.
# kyc-api reads shared payments-api/* secrets (DB, Redis, JWT).

resource "aws_iam_role" "kyc_api_execution" {
  name        = "${var.name_prefix}-kyc-api-execution-role"
  description = "ECS execution role for kyc-api - pulls secrets and images"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "kyc_api_execution_managed" {
  role       = aws_iam_role.kyc_api_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "kyc_api_execution_secrets" {
  name = "${var.name_prefix}-kyc-api-execution-secrets"
  role = aws_iam_role.kyc_api_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # kyc-api needs payments-api/* secrets (shared DB, Redis, JWT public key)
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/payments-api/*",
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/kyc-api/*"
        ]
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ── kyc-api Task Role ─────────────────────────────────────────────────────────
# Used by APPLICATION CODE inside the running container.

resource "aws_iam_role" "kyc_api_task" {
  name        = "${var.name_prefix}-kyc-api-task-role"
  description = "ECS task role for kyc-api - least privilege runtime permissions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "kyc_api_task" {
  name = "${var.name_prefix}-kyc-api-task-policy"
  role = aws_iam_role.kyc_api_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3KYCDocuments"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.name_prefix}-kyc-documents/*"
      },
      {
        Sid      = "S3KYCList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.name_prefix}-kyc-documents"
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.name_prefix}/kyc-api:*"
      }
    ]
  })
}

# ── GitHub Actions OIDC Provider ──────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-github-actions-oidc"
  })
}

# ── GitHub Actions Deployment Role ────────────────────────────────────────────

resource "aws_iam_role" "github_actions_deploy" {
  name        = "${var.name_prefix}-github-actions-deploy-role"
  description = "GitHub Actions deployment role - least privilege, no AdministratorAccess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "${var.name_prefix}-github-actions-deploy-policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.name_prefix}/payments-api",
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.name_prefix}/kyc-api"
        ]
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassTaskRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.payments_api_execution.arn,
          aws_iam_role.payments_api_task.arn,
          aws_iam_role.kyc_api_execution.arn,
          aws_iam_role.kyc_api_task.arn
        ]
      },
      {
        Sid    = "ECSWait"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      }
    ]
  })
}
