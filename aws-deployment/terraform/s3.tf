# s3.tf - S3 configuration for hosting the F1 Telemetry WebApp

# Random string for bucket name suffix
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for webapp hosting
resource "aws_s3_bucket" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  bucket = "${var.webapp_bucket_name}-${var.stage}-${random_string.bucket_suffix.id}"
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-webapp-bucket-${var.stage}"
    Environment = var.stage
  })
}

# S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  bucket = aws_s3_bucket.webapp[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 bucket ACL
resource "aws_s3_bucket_acl" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  bucket = aws_s3_bucket.webapp[0].id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.webapp[0]]
}

# S3 bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "webapp_cloudfront_access" {
  count = var.deploy_webapp ? 1 : 0
  
  bucket = aws_s3_bucket.webapp[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.webapp[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.webapp[0].arn
          }
        }
      }
    ]
  })
  depends_on = [aws_cloudfront_distribution.webapp]
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "webapp" {
  count = var.deploy_webapp ? 1 : 0
  
  bucket = aws_s3_bucket.webapp[0].id
  
  index_document {
    suffix = "index.html"
  }
  
  error_document {
    key = "index.html" # For SPA routing
  }
}

# S3 bucket for Lambda packages
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.lambda_bucket_name}-${var.stage}-${random_string.bucket_suffix.id}"
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-lambda-bucket-${var.stage}"
    Environment = var.stage
  })
}

# S3 bucket ownership controls for Lambda bucket
resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 bucket ACL for Lambda bucket
resource "aws_s3_bucket_acl" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]
}

# S3 bucket versioning for Lambda bucket
resource "aws_s3_bucket_versioning" "lambda_bucket_versioning" {
  bucket = aws_s3_bucket.lambda_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 lifecycle policy to clean up old Lambda versions
resource "aws_s3_bucket_lifecycle_configuration" "lambda_bucket_lifecycle" {
  bucket = aws_s3_bucket.lambda_bucket.id
  
  rule {
    id      = "cleanup-old-versions"
    status  = "Enabled"
    
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# S3 bucket for CloudFront access logs (if enabled)
resource "aws_s3_bucket" "cloudfront_logs" {
  count = var.enable_cloudfront_logging && var.deploy_webapp ? 1 : 0
  
  bucket = "cloudfront-logs-${var.stage}-${random_string.bucket_suffix.id}"
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-cloudfront-logs-${var.stage}"
    Environment = var.stage
  })
}

# S3 bucket ownership controls for CloudFront logs
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  count = var.enable_cloudfront_logging && var.deploy_webapp ? 1 : 0
  
  bucket = aws_s3_bucket.cloudfront_logs[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 bucket ACL for CloudFront logs
resource "aws_s3_bucket_acl" "cloudfront_logs" {
  count = var.enable_cloudfront_logging && var.deploy_webapp ? 1 : 0
  
  bucket = aws_s3_bucket.cloudfront_logs[0].id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs[0]]
}

# S3 bucket lifecycle policy for CloudFront logs
resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs_lifecycle" {
  count = var.enable_cloudfront_logging && var.deploy_webapp ? 1 : 0
  
  bucket = aws_s3_bucket.cloudfront_logs[0].id
  
  rule {
    id      = "logs-cleanup"
    status  = "Enabled"
    
    expiration {
      days = 90
    }
  }
}

# Output the webapp bucket name
output "s3_webapp_bucket" {
  description = "S3 bucket hosting the webapp"
  value       = var.deploy_webapp ? aws_s3_bucket.webapp[0].bucket : null
}

# Output the webapp bucket website endpoint
output "s3_webapp_website_endpoint" {
  description = "S3 website endpoint for the webapp"
  value       = var.deploy_webapp ? aws_s3_bucket_website_configuration.webapp[0].website_endpoint : null
}

# Output the lambda package bucket name
output "s3_lambda_bucket" {
  description = "S3 bucket for Lambda packages"
  value       = aws_s3_bucket.lambda_bucket.bucket
}