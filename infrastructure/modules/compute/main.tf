# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── ECR Repositories ──────────────────────────────────────────────────────────

resource "aws_ecr_repository" "payments_api" {
  name                 = "${var.name_prefix}/payments-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-payments-api-ecr"
  })
}

resource "aws_ecr_repository" "kyc_api" {
  name                 = "${var.name_prefix}/kyc-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-kyc-api-ecr"
  })
}

resource "aws_ecr_lifecycle_policy" "payments_api" {
  repository = aws_ecr_repository.payments_api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "kyc_api" {
  repository = aws_ecr_repository.kyc_api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "payments_api" {
  name              = "/ecs/${var.name_prefix}/payments-api"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-payments-api-logs"
  })
}

resource "aws_cloudwatch_log_group" "kyc_api" {
  name              = "/ecs/${var.name_prefix}/kyc-api"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-kyc-api-logs"
  })
}

# ── payments-api Task Definition ──────────────────────────────────────────────

resource "aws_ecs_task_definition" "payments_api" {
  family                   = "${var.name_prefix}-payments-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  task_role_arn            = var.payments_api_task_role_arn
  execution_role_arn       = var.payments_api_task_role_arn

  container_definitions = jsonencode([{
    name  = "payments-api"
    image = var.payments_api_image != "" ? var.payments_api_image : "${aws_ecr_repository.payments_api.repository_url}:latest"

    portMappings = [{
      containerPort = var.payments_api_port
      protocol      = "tcp"
    }]

    secrets = [
      {
        name      = "DATABASE_URL"
        valueFrom = var.db_secret_arn
      },
      {
        name      = "REDIS_AUTH_TOKEN"
        valueFrom = var.redis_auth_secret_arn
      },
      {
        name      = "JWT_PRIVATE_KEY"
        valueFrom = var.jwt_private_key_secret_arn
      },
      {
        name      = "JWT_PUBLIC_KEY"
        valueFrom = var.jwt_public_key_secret_arn
      }
    ]

    environment = [
      {
        name  = "ENVIRONMENT"
        value = "production"
      },
      {
        name  = "PORT"
        value = tostring(var.payments_api_port)
      }
    ]

    # Read-only root filesystem with tmpfs for /tmp (Fargate compatible)
    readonlyRootFilesystem = true
    user                   = "1001:1001"

    linuxParameters = {
      capabilities = {
        drop = ["ALL"]
      }
      tmpfs = [{
        containerPath = "/tmp"
        size          = 64
      }]
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.payments_api.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.payments_api_port}/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-payments-api-task"
  })
}

# ── kyc-api Task Definition ───────────────────────────────────────────────────

resource "aws_ecs_task_definition" "kyc_api" {
  family                   = "${var.name_prefix}-kyc-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  task_role_arn            = var.kyc_api_task_role_arn
  execution_role_arn       = var.kyc_api_task_role_arn

  container_definitions = jsonencode([{
    name  = "kyc-api"
    image = var.kyc_api_image != "" ? var.kyc_api_image : "${aws_ecr_repository.kyc_api.repository_url}:latest"

    portMappings = [{
      containerPort = var.kyc_api_port
      protocol      = "tcp"
    }]

    secrets = [
      {
        name      = "DATABASE_URL"
        valueFrom = var.db_secret_arn
      },
      {
        name      = "REDIS_AUTH_TOKEN"
        valueFrom = var.redis_auth_secret_arn
      },
      {
        name      = "JWT_PUBLIC_KEY"
        valueFrom = var.jwt_public_key_secret_arn
      },
    ]

    environment = [
      {
        name  = "ENVIRONMENT"
        value = "production"
      },
      {
        name  = "PORT"
        value = tostring(var.kyc_api_port)
      },
      {
        name  = "KYC_BUCKET"
        value = var.kyc_bucket_name
      }
    ]

    readonlyRootFilesystem = true
    user                   = "1001:1001"

    linuxParameters = {
      capabilities = {
        drop = ["ALL"]
      }
      tmpfs = [{
        containerPath = "/tmp"
        size          = 64
      }]
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.kyc_api.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.kyc_api_port}/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-kyc-api-task"
  })
}

# ── ECS Services ──────────────────────────────────────────────────────────────

resource "aws_ecs_service" "payments_api" {
  name            = "${var.name_prefix}-payments-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payments_api.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.payments_api_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_payments
    container_name   = "payments-api"
    container_port   = var.payments_api_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-payments-api-service"
  })

  depends_on = [var.alb_target_group_payments]
}

resource "aws_ecs_service" "kyc_api" {
  name            = "${var.name_prefix}-kyc-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.kyc_api.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.kyc_api_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_kyc
    container_name   = "kyc-api"
    container_port   = var.kyc_api_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-kyc-api-service"
  })

  depends_on = [var.alb_target_group_kyc]
}
