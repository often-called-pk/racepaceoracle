# variables.tf - Input variables for the F1 Telemetry WebApp

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "stage" {
  description = "Deployment stage (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "environment" {
  description = "Environment type (e.g., development, production)"
  type        = string
  default     = "development"
}

variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "F1TelemetryWebapp"
    ManagedBy   = "Terraform"
    Application = "F1Telemetry"
  }
}

# S3 Configuration
variable "deploy_webapp" {
  description = "Whether to deploy the webapp frontend"
  type        = bool
  default     = true
}

variable "webapp_bucket_name" {
  description = "Name for the S3 bucket to host the webapp (will be prefixed with f1-telemetry-webapp-)"
  type        = string
  default     = "webapp"
}

variable "lambda_bucket_name" {
  description = "Name for the S3 bucket to store Lambda packages"
  type        = string
  default     = "lambda-packages"
}

# DynamoDB Configuration
variable "telemetry_table_name" {
  description = "Name for the DynamoDB table to store telemetry data"
  type        = string
  default     = "f1-telemetry"
}

variable "driver_table_name" {
  description = "Name for the DynamoDB table to store driver data"
  type        = string
  default     = "f1-drivers"
}

variable "lap_table_name" {
  description = "Name for the DynamoDB table to store lap data"
  type        = string
  default     = "f1-laps"
}

variable "read_capacity" {
  description = "Read capacity units for DynamoDB tables"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units for DynamoDB tables"
  type        = number
  default     = 5
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions (MB)"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions (seconds)"
  type        = number
  default     = 30
}

variable "provisioned_concurrency" {
  description = "Provisioned concurrency for Lambda functions (0 to disable)"
  type        = number
  default     = 0
}

variable "enable_lambda_warm_up" {
  description = "Enable periodic warm-up of Lambda functions"
  type        = bool
  default     = false
}

# API Gateway Configuration
variable "api_throttling_rate_limit" {
  description = "API Gateway throttling rate limit"
  type        = number
  default     = 100
}

variable "api_throttling_burst_limit" {
  description = "API Gateway throttling burst limit"
  type        = number
  default     = 50
}

variable "enable_api_caching" {
  description = "Enable API Gateway caching"
  type        = bool
  default     = false
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "Price class for CloudFront distribution"
  type        = string
  default     = "PriceClass_100" # Use PriceClass_All for global distribution
}

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

# Custom Domain Configuration
variable "enable_custom_domain" {
  description = "Enable custom domain for the webapp"
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Custom domain name for the webapp (e.g., f1telemetry.example.com)"
  type        = string
  default     = ""
}

# X-Ray Configuration
variable "enable_xray" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}