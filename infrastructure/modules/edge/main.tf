# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── Self-signed TLS Certificate ───────────────────────────────────────────────
# Used because we have no domain name for this engagement.
# With a real domain: replace with aws_acm_certificate + DNS validation.

resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = "${var.name_prefix}.local"
    organization = "SentinelPay Technologies"
  }

  # Valid for 1 year
  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb" {
  private_key      = tls_private_key.alb.private_key_pem
  certificate_body = tls_self_signed_cert.alb.cert_pem

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb-cert"
    Note = "Self-signed cert - replace with ACM public cert when domain is available"
  })
}

# ── Application Load Balancer ─────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true
  enable_http2               = true

  # ALB access logs disabled — audit bucket uses Object Lock (Compliance mode)
  # which is incompatible with ALB log delivery. WAF logs go to CloudWatch instead.
  access_logs {
    bucket  = var.audit_bucket_name
    enabled = false
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# ── HTTPS Listener (port 443) ─────────────────────────────────────────────────

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb.arn

  # Default action - return 404 for unknown paths
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\": \"not found\"}"
      status_code  = "404"
    }
  }

  tags = var.common_tags
}

# ── HTTP Listener (port 80) - redirects to HTTPS ──────────────────────────────

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.common_tags
}

# ── Target Groups ─────────────────────────────────────────────────────────────

resource "aws_lb_target_group" "payments_api" {
  name        = "${var.name_prefix}-pay-tg"
  port        = var.payments_api_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-payments-tg"
  })
}

resource "aws_lb_target_group" "kyc_api" {
  name        = "${var.name_prefix}-kyc-tg"
  port        = var.kyc_api_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-kyc-tg"
  })
}

# ── Listener Rules ────────────────────────────────────────────────────────────

resource "aws_lb_listener_rule" "payments_api_auth" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payments_api.arn
  }

  condition {
    path_pattern {
      values = ["/v1/auth/*", "/v1/accounts/*", "/v1/transactions/*", "/v1/wallets/*", "/health"]
    }
  }

  tags = var.common_tags
}

resource "aws_lb_listener_rule" "payments_api_webhooks" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payments_api.arn
  }

  condition {
    path_pattern {
      values = ["/v1/webhooks/*", "/v1/admin/*"]
    }
  }

  tags = var.common_tags
}

resource "aws_lb_listener_rule" "kyc_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kyc_api.arn
  }

  condition {
    path_pattern {
      values = ["/v1/verify/*", "/v1/documents/*"]
    }
  }

  tags = var.common_tags
}

# ── WAF Web ACL ───────────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-waf"
  description = "SentinelPay WAF - SQLi, XSS, common rules, rate limiting"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed - SQL Injection Rule Set
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-bad-inputs-rules"
      sampled_requests_enabled   = true
    }
  }

  # Custom rate limit rule - payments path
  rule {
    name     = "PaymentsRateLimit"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = "/v1/wallets"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-payments-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-waf"
  })
}

# ── Attach WAF to ALB ─────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ── WAF Logging — CloudWatch Logs ────────────────────────────────────────────
# WAF does not support direct S3 logging — requires CloudWatch or Firehose.

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = 30

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-waf-logs"
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
      requirement = "MEETS_ANY"
    }
  }
}
