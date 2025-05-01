# Route53 configuration for the F1 Telemetry WebApp

# Conditional creation based on custom domain setting
locals {
  create_route53_records = var.enable_custom_domain && var.custom_domain_name != "" && var.deploy_webapp
}

# Fetch the hosted zone data based on the domain name
data "aws_route53_zone" "custom_domain" {
  count = local.create_route53_records ? 1 : 0
  
  name         = var.custom_domain_name
  private_zone = false
}

# DNS record for the custom domain pointing to CloudFront
resource "aws_route53_record" "custom_domain" {
  count = local.create_route53_records ? 1 : 0
  
  zone_id = data.aws_route53_zone.custom_domain[0].id
  name    = var.custom_domain_name
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.webapp[0].domain_name
    zone_id                = aws_cloudfront_distribution.webapp[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# DNS record for www subdomain
resource "aws_route53_record" "www" {
  count = local.create_route53_records ? 1 : 0
  
  zone_id = data.aws_route53_zone.custom_domain[0].id
  name    = "www.${var.custom_domain_name}"
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.webapp[0].domain_name
    zone_id                = aws_cloudfront_distribution.webapp[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# Certificate validation records
resource "aws_route53_record" "cert_validation" {
  for_each = local.create_route53_records ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.custom_domain[0].zone_id
}

# API Gateway custom domain (optional)
resource "aws_api_gateway_domain_name" "api_custom_domain" {
  count = local.create_route53_records ? 1 : 0
  
  domain_name = "api.${var.custom_domain_name}"
  
  regional_certificate_arn = aws_acm_certificate_validation.cert[0].certificate_arn
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway base path mapping
resource "aws_api_gateway_base_path_mapping" "api_mapping" {
  count = local.create_route53_records ? 1 : 0
  
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  domain_name = aws_api_gateway_domain_name.api_custom_domain[0].domain_name
}

# DNS record for API Gateway custom domain
resource "aws_route53_record" "api_custom_domain" {
  count = local.create_route53_records ? 1 : 0
  
  zone_id = data.aws_route53_zone.custom_domain[0].zone_id
  name    = "api.${var.custom_domain_name}"
  type    = "A"
  
  alias {
    name                   = aws_api_gateway_domain_name.api_custom_domain[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.api_custom_domain[0].regional_zone_id
    evaluate_target_health = false
  }
}

# Health check for the web app (optional)
resource "aws_route53_health_check" "webapp" {
  count = local.create_route53_records ? 1 : 0
  
  fqdn              = var.custom_domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-health-check-${var.stage}"
    Environment = var.stage
  })
}

# CloudWatch alarm for Route53 health check
resource "aws_cloudwatch_metric_alarm" "webapp_health" {
  count = local.create_route53_records ? 1 : 0
  
  alarm_name          = "${local.service_name}-webapp-health-${var.stage}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "This metric monitors webapp health via Route53 health check"
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.webapp[0].id
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-webapp-health-alarm-${var.stage}"
    Environment = var.stage
  })
}

# Output custom domain information
output "custom_domain_url" {
  description = "Custom domain URL for the webapp (if enabled)"
  value       = local.create_route53_records ? "https://${var.custom_domain_name}" : null
}

output "api_custom_domain_url" {
  description = "Custom domain URL for the API (if enabled)"
  value       = local.create_route53_records ? "https://api.${var.custom_domain_name}" : null
}