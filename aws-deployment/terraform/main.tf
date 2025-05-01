# Main Terraform configuration for the F1 Telemetry WebApp

# Local variables
locals {
  service_name = "f1-telemetry"
}

# AWS provider configuration
provider "aws" {
  region = var.region
  
  default_tags {
    tags = var.tags
  }
}

# US East 1 region provider for ACM certificates (required for CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags {
    tags = var.tags
  }
}

# Random provider for generating unique identifiers
provider "random" {
}

# Terraform settings
terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
  
  # Optional S3 backend for remote state (uncomment and configure as needed)
  /*
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "f1-telemetry-webapp/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
  */
}

# CloudWatch Dashboard for monitoring overall application
resource "aws_cloudwatch_dashboard" "main_dashboard" {
  dashboard_name = "${local.service_name}-dashboard-${var.stage}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text",
        x      = 0,
        y      = 0,
        width  = 24,
        height = 1,
        properties = {
          markdown = "# F1 Telemetry WebApp - ${upper(var.stage)} Environment"
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 1,
        width  = 8,
        height = 6,
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.telemetry.function_name],
            [".", ".", ".", aws_lambda_function.driver_data.function_name],
            [".", ".", ".", aws_lambda_function.race_data.function_name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "Lambda Invocations",
          stat     = "Sum",
          period   = 300
        }
      },
      {
        type   = "metric",
        x      = 8,
        y      = 1,
        width  = 8,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", aws_api_gateway_stage.api_stage.stage_name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "API Requests",
          stat     = "Sum",
          period   = 300
        }
      },
      {
        type   = "metric",
        x      = 16,
        y      = 1,
        width  = 8,
        height = 6,
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.telemetry.name],
            [".", "ConsumedWriteCapacityUnits", ".", aws_dynamodb_table.telemetry.name],
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "DynamoDB Consumption",
          stat     = "Sum",
          period   = 300
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 7,
        width  = 8,
        height = 6,
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.telemetry.function_name],
            [".", ".", ".", aws_lambda_function.driver_data.function_name],
            [".", ".", ".", aws_lambda_function.race_data.function_name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "Lambda Errors",
          stat     = "Sum",
          period   = 300
        }
      },
      {
        type   = "metric",
        x      = 8,
        y      = 7,
        width  = 8,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", aws_api_gateway_stage.api_stage.stage_name],
            [".", "5XXError", ".", ".", ".", "."]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "API Errors",
          stat     = "Sum",
          period   = 300
        }
      }
    ]
  })
}