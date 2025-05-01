# IAM configuration for the F1 Telemetry WebApp

# Lambda IAM role
resource "aws_iam_role" "lambda_role" {
  name = "${local.service_name}-lambda-role-${var.stage}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-lambda-role-${var.stage}"
    Environment = var.stage
  })
}

# Lambda policy for DynamoDB access
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${local.service_name}-lambda-dynamodb-policy-${var.stage}"
  description = "IAM policy for Lambda to access DynamoDB tables"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.telemetry.arn,
          "${aws_dynamodb_table.telemetry.arn}/index/*",
          aws_dynamodb_table.drivers.arn,
          "${aws_dynamodb_table.drivers.arn}/index/*",
          aws_dynamodb_table.laps.arn,
          "${aws_dynamodb_table.laps.arn}/index/*"
        ]
      }
    ]
  })
}

# Lambda policy for CloudWatch Logs
resource "aws_iam_policy" "lambda_logs_policy" {
  name        = "${local.service_name}-lambda-logs-policy-${var.stage}"
  description = "IAM policy for Lambda to write logs to CloudWatch"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda policy for X-Ray tracing
resource "aws_iam_policy" "lambda_xray_policy" {
  count = var.enable_xray ? 1 : 0
  
  name        = "${local.service_name}-lambda-xray-policy-${var.stage}"
  description = "IAM policy for Lambda to use X-Ray tracing"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach policies to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count      = var.enable_xray ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_xray_policy[0].arn
}

# Lambda basic execution role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway CloudWatch role
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.service_name}-api-cloudwatch-role-${var.stage}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-api-cloudwatch-role-${var.stage}"
    Environment = var.stage
  })
}

# API Gateway CloudWatch policy
resource "aws_iam_policy" "api_gateway_cloudwatch_policy" {
  name        = "${local.service_name}-api-cloudwatch-policy-${var.stage}"
  description = "IAM policy for API Gateway to write logs to CloudWatch"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach CloudWatch policy to API Gateway role
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = aws_iam_policy.api_gateway_cloudwatch_policy.arn
}

# S3 deployment role (optional - for webapp deployment)
resource "aws_iam_role" "s3_deployment_role" {
  count = var.deploy_webapp ? 1 : 0
  
  name = "${local.service_name}-s3-deployment-role-${var.stage}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-s3-deployment-role-${var.stage}"
    Environment = var.stage
  })
}

# S3 deployment policy
resource "aws_iam_policy" "s3_deployment_policy" {
  count = var.deploy_webapp ? 1 : 0
  
  name        = "${local.service_name}-s3-deployment-policy-${var.stage}"
  description = "IAM policy for deploying to S3 and invalidating CloudFront"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.webapp[0].arn,
          "${aws_s3_bucket.webapp[0].arn}/*"
        ]
      },
      {
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach S3 deployment policy
resource "aws_iam_role_policy_attachment" "s3_deployment" {
  count      = var.deploy_webapp ? 1 : 0
  role       = aws_iam_role.s3_deployment_role[0].name
  policy_arn = aws_iam_policy.s3_deployment_policy[0].arn
}