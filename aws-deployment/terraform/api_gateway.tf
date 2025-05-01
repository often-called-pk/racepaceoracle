# API Gateway configuration for the F1 Telemetry WebApp

# REST API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "${local.service_name}-api-${var.stage}"
  description = "F1 Telemetry WebApp API"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-api-${var.stage}"
    Environment = var.stage
  })
}

# API Gateway resource for telemetry endpoint
resource "aws_api_gateway_resource" "telemetry" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "telemetry"
}

# API Gateway resource for driver data endpoint
resource "aws_api_gateway_resource" "drivers" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "drivers"
}

# API Gateway resource for race data endpoint
resource "aws_api_gateway_resource" "races" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "races"
}

# GET method for telemetry endpoint
resource "aws_api_gateway_method" "telemetry_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.telemetry.id
  http_method   = "GET"
  authorization_type = "NONE"
  
  request_parameters = {
    "method.request.querystring.session_uid" = true
    "method.request.querystring.driver_id"   = false
    "method.request.querystring.lap_number"  = false
  }
}

# GET method for driver data endpoint
resource "aws_api_gateway_method" "drivers_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.drivers.id
  http_method   = "GET"
  authorization_type = "NONE"
  
  request_parameters = {
    "method.request.querystring.session_uid" = true
    "method.request.querystring.driver_id"   = false
  }
}

# GET method for race data endpoint
resource "aws_api_gateway_method" "races_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.races.id
  http_method   = "GET"
  authorization_type = "NONE"
  
  request_parameters = {
    "method.request.querystring.session_uid" = true
  }
}

# Integration for telemetry endpoint with Lambda
resource "aws_api_gateway_integration" "telemetry_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.telemetry.id
  http_method             = aws_api_gateway_method.telemetry_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.telemetry.invoke_arn
}

# Integration for driver data endpoint with Lambda
resource "aws_api_gateway_integration" "drivers_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.drivers.id
  http_method             = aws_api_gateway_method.drivers_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.driver_data.invoke_arn
}

# Integration for race data endpoint with Lambda
resource "aws_api_gateway_integration" "races_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.races.id
  http_method             = aws_api_gateway_method.races_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.race_data.invoke_arn
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.telemetry_integration,
    aws_api_gateway_integration.drivers_integration,
    aws_api_gateway_integration.races_integration
  ]
  
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.stage
  
  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway stage settings
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage
  
  # Enable caching if specified
  dynamic "cache_cluster_settings" {
    for_each = var.enable_api_caching ? [1] : []
    content {
      enable_cache_clustering = true
      cache_cluster_size      = "0.5"
    }
  }
  
  # Enable X-Ray tracing if specified
  dynamic "xray_tracing_enabled" {
    for_each = var.enable_xray ? [1] : []
    content {
      xray_tracing_enabled = true
    }
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-api-stage-${var.stage}"
    Environment = var.stage
  })
}

# API Gateway method settings for caching
resource "aws_api_gateway_method_settings" "api_settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  method_path = "*/*"
  
  settings {
    metrics_enabled        = true
    data_trace_enabled     = var.stage != "production"
    logging_level          = var.stage == "production" ? "INFO" : "DEBUG"
    throttling_rate_limit  = var.api_throttling_rate_limit
    throttling_burst_limit = var.api_throttling_burst_limit
    caching_enabled        = var.enable_api_caching
    cache_ttl_in_seconds   = var.enable_api_caching ? 300 : 0
  }
}

# API Gateway usage plan
resource "aws_api_gateway_usage_plan" "api_usage_plan" {
  name        = "${local.service_name}-usage-plan-${var.stage}"
  description = "Usage plan for F1 Telemetry WebApp API"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.api_stage.stage_name
  }
  
  quota_settings {
    limit  = 10000
    period = "MONTH"
  }
  
  throttle_settings {
    burst_limit = var.api_throttling_burst_limit
    rate_limit  = var.api_throttling_rate_limit
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-usage-plan-${var.stage}"
    Environment = var.stage
  })
}

# CORS configuration for API Gateway
resource "aws_api_gateway_resource" "cors_preflight" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "cors_preflight" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.cors_preflight.id
  http_method   = "OPTIONS"
  authorization_type = "NONE"
}

resource "aws_api_gateway_integration" "cors_preflight" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.cors_preflight.id
  http_method   = aws_api_gateway_method.cors_preflight.http_method
  type          = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors_preflight" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.cors_preflight.id
  http_method   = aws_api_gateway_method.cors_preflight.http_method
  status_code   = "200"
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "cors_preflight" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.cors_preflight.id
  http_method   = aws_api_gateway_method.cors_preflight.http_method
  status_code   = aws_api_gateway_method_response.cors_preflight.status_code
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [
    aws_api_gateway_method_response.cors_preflight
  ]
}

# API Gateway CloudWatch logs
resource "aws_api_gateway_account" "api_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# CloudWatch alarms for API Gateway errors
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${local.service_name}-api-5xx-errors-${var.stage}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "API Gateway 5XX error rate is too high"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.api.name
    Stage   = aws_api_gateway_stage.api_stage.stage_name
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-api-alarm-${var.stage}"
    Environment = var.stage
  })
}

# CloudWatch dashboard for API Gateway
resource "aws_cloudwatch_dashboard" "api_dashboard" {
  dashboard_name = "${local.service_name}-api-dashboard-${var.stage}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", aws_api_gateway_stage.api_stage.stage_name, "Resource", "/telemetry", "Method", "GET"],
            ["...", "/drivers", ".", "."],
            ["...", "/races", ".", "."]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "API Request Count",
          stat     = "Sum",
          period   = 300
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 6,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", aws_api_gateway_stage.api_stage.stage_name],
            [".", "IntegrationLatency", ".", ".", ".", "."]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "API Latency",
          stat     = "Average",
          period   = 300
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 12,
        width  = 12,
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

# Output the API Gateway URL
output "api_url" {
  description = "URL of the API Gateway"
  value       = aws_api_gateway_deployment.api_deployment.invoke_url
}

output "telemetry_endpoint" {
  description = "Telemetry API endpoint"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/telemetry"
}

output "drivers_endpoint" {
  description = "Drivers API endpoint"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/drivers"
}

output "races_endpoint" {
  description = "Races API endpoint"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/races"
}