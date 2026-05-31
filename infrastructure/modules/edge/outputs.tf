output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name - use this to reach the API"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID"
  value       = aws_lb.main.zone_id
}

output "payments_target_group_arn" {
  description = "Target group ARN for payments-api"
  value       = aws_lb_target_group.payments_api.arn
}

output "kyc_target_group_arn" {
  description = "Target group ARN for kyc-api"
  value       = aws_lb_target_group.kyc_api.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "https_listener_arn" {
  description = "HTTPS listener ARN"
  value       = aws_lb_listener.https.arn
}
