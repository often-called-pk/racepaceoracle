# cloudfront.tf - CloudFront configuration for the F1 Telemetry WebApp

# Create ACM certificate for custom domain (if enabled)
resource "aws_acm_certificate" "cert" {
  count = var.enable_custom_domain && var.custom_domain_name != "" && var.deploy_webapp ? 1 : 0
  
  provider = aws.us_east_1  # CloudFront requires certificates in us-east-1
  domain_name       = var.custom_domain_name
  validation_method = "DNS"
  
  subject_alternative_names = [
    "www.${var.custom_domain_name}",
    "api.${var.custom_domain_name}"
  ]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-cert-${var.stage}"
    Environment = var.stage
  })
}

# Certificate validation (if using custom domain)
resource "aws_acm_certificate_validation" "cert" {
  count = var.enable_custom_domain && var.custom_domain_name != "" && var.deploy_webapp ? 1 : 0
  
  provider = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudFront Origin Access Identity (OAI) for S3
resource "aws_cloudfront_origin_access_identity" "webapp_oai" {
  count = var.deploy_webapp ? 1 : 0
  
  comment = "OAI for ${local.service_name} webapp"
}

# CloudFront Cache Policy
resource "aws_cloudfront_cache_policy" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  name        = "${local.service_name}-cache-policy-${var.stage}"
  comment     = "Cache policy for ${local.service_name} webapp"
  default_ttl = 3600
  max_ttl     = 86400
  min_ttl     = 1
  
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# CloudFront Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  count = var.deploy_webapp ? 1 : 0
  
  name    = "${local.service_name}-security-headers-${var.stage}"
  comment = "Security headers policy for ${local.service_name} webapp"
  
  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains = true
      preload = true
      override = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self' https://api.${var.custom_domain_name} https://*.amazonaws.com; img-src 'self' data: https://*.amazonaws.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https://api.${var.custom_domain_name} https://*.amazonaws.com;"
      override = true
    }
  }
}

# CloudFront distribution for webapp
resource "aws_cloudfront_distribution" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.service_name} webapp distribution - ${var.stage}"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  
  # S3 origin
  origin {
    domain_name              = aws_s3_bucket.webapp[0].bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.webapp[0].bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.webapp[0].id
  }
  
  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "S3-${aws_s3_bucket.webapp[0].bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    
    # Use cache policy and response headers policy
    cache_policy_id            = aws_cloudfront_cache_policy.webapp[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers[0].id
    
    # Lambda function associations (if needed)
    # lambda_function_association {
    #   event_type   = "viewer-request"
    #   lambda_arn   = ""
    #   include_body = false
    # }
  }
  
  # SPA routing - serve index.html for all routes
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }
  
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }
  
  # Alternate domain names (CNAME) if custom domain is enabled
  dynamic "aliases" {
    for_each = var.enable_custom_domain && var.custom_domain_name != "" ? [1] : []
    content {
      items = [
        var.custom_domain_name,
        "www.${var.custom_domain_name}"
      ]
    }
  }
  
  # SSL certificate if custom domain is enabled
  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain && var.custom_domain_name != "" ? [1] : []
    content {
      acm_certificate_arn      = aws_acm_certificate_validation.cert[0].certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }
  
  # Default CloudFront certificate if custom domain is not enabled
  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain && var.custom_domain_name != "" ? [] : [1]
    content {
      cloudfront_default_certificate = true
    }
  }
  
  # Geo restrictions (none)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  # Logging configuration (if enabled)
  dynamic "logging_config" {
    for_each = var.enable_cloudfront_logging ? [1] : []
    content {
      include_cookies = false
      bucket          = aws_s3_bucket.cloudfront_logs[0].bucket_regional_domain_name
      prefix          = "cloudfront-logs/"
    }
  }
  
  # Wait for certificate validation if using custom domain
  depends_on = [
    aws_acm_certificate_validation.cert
  ]
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-cloudfront-${var.stage}"
    Environment = var.stage
  })
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  name                              = "${local.service_name}-oac-${var.stage}"
  description                       = "Origin Access Control for ${local.service_name} S3 webapp bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront monitoring
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  count = var.deploy_webapp ? 1 : 0
  
  alarm_name          = "${local.service_name}-cloudfront-5xx-errors-${var.stage}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "CloudFront 5XX error rate is too high"
  
  dimensions = {
    DistributionId = aws_cloudfront_distribution.webapp[0].id
    Region         = "Global"
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-cloudfront-alarm-${var.stage}"
    Environment = var.stage
  })
}