# Output configuration for the F1 Telemetry WebApp

# Web App Outputs
output "webapp_url" {
  description = "URL of the deployed webapp"
  value       = var.deploy_webapp ? "https://${aws_cloudfront_distribution.webapp[0].domain_name}" : null
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = var.deploy_webapp ? aws_cloudfront_distribution.webapp[0].domain_name : null
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.deploy_webapp ? aws_cloudfront_distribution.webapp[0].id : null
}

output "webapp_bucket_name" {
  description = "Name of the S3 bucket hosting the webapp"
  value       = var.deploy_webapp ? aws_s3_bucket.webapp[0].bucket : null
}

# API Gateway Outputs
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}${var.stage}"
}

# DynamoDB Table Outputs
output "telemetry_table_name" {
  description = "Name of the DynamoDB table for telemetry data"
  value       = aws_dynamodb_table.telemetry.name
}

output "driver_table_name" {
  description = "Name of the DynamoDB table for driver data"
  value       = aws_dynamodb_table.drivers.name
}

output "lap_table_name" {
  description = "Name of the DynamoDB table for lap data"
  value       = aws_dynamodb_table.laps.name
}

# Lambda Function Outputs
output "telemetry_lambda_arn" {
  description = "ARN of the Telemetry Lambda function"
  value       = aws_lambda_function.telemetry.arn
}

output "driver_data_lambda_arn" {
  description = "ARN of the Driver Data Lambda function"
  value       = aws_lambda_function.driver_data.arn
}

output "race_data_lambda_arn" {
  description = "ARN of the Race Data Lambda function"
  value       = aws_lambda_function.race_data.arn
}

# Deployment Command Outputs
output "s3_sync_command" {
  description = "Command to sync webapp build files to S3"
  value       = var.deploy_webapp ? "aws s3 sync ./build/ s3://${aws_s3_bucket.webapp[0].bucket} --delete" : null
}

output "cloudfront_invalidation_command" {
  description = "Command to invalidate CloudFront cache"
  value       = var.deploy_webapp ? "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.webapp[0].id} --paths \"/*\"" : null
}

# Region Information
output "deployment_region" {
  description = "AWS region where resources are deployed"
  value       = var.region
}

output "deployment_stage" {
  description = "Deployment stage"
  value       = var.stage
}