# Lambda configuration for the F1 Telemetry WebApp

# Archive files from dist directory
data "archive_file" "telemetry_lambda" {
  type        = "zip"
  source_file = "${path.module}/../dist/telemetry.zip"
  output_path = "${path.module}/../dist/telemetry_lambda_package.zip"
  depends_on  = [null_resource.build_lambdas]
}

data "archive_file" "driver_data_lambda" {
  type        = "zip"
  source_file = "${path.module}/../dist/driver_data.zip"
  output_path = "${path.module}/../dist/driver_data_lambda_package.zip"
  depends_on  = [null_resource.build_lambdas]
}

data "archive_file" "race_data_lambda" {
  type        = "zip"
  source_file = "${path.module}/../dist/race_data.zip"
  output_path = "${path.module}/../dist/race_data_lambda_package.zip"
  depends_on  = [null_resource.build_lambdas]
}

# Make sure Lambda packages are built before Terraform execution
resource "null_resource" "build_lambdas" {
  provisioner "local-exec" {
    command = "python ${path.module}/../scripts/build_lambdas.py"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

# S3 uploads for Lambda packages
resource "aws_s3_object" "telemetry_lambda_package" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_packages/telemetry_${filemd5(data.archive_file.telemetry_lambda.output_path)}.zip"
  source = data.archive_file.telemetry_lambda.output_path
  etag   = filemd5(data.archive_file.telemetry_lambda.output_path)
}

resource "aws_s3_object" "driver_data_lambda_package" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_packages/driver_data_${filemd5(data.archive_file.driver_data_lambda.output_path)}.zip"
  source = data.archive_file.driver_data_lambda.output_path
  etag   = filemd5(data.archive_file.driver_data_lambda.output_path)
}

resource "aws_s3_object" "race_data_lambda_package" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_packages/race_data_${filemd5(data.archive_file.race_data_lambda.output_path)}.zip"
  source = data.archive_file.race_data_lambda.output_path
  etag   = filemd5(data.archive_file.race_data_lambda.output_path)
}

# Telemetry Lambda function
resource "aws_lambda_function" "telemetry" {
  function_name = "${local.service_name}-telemetry-${var.stage}"
  description   = "Lambda function to handle telemetry data requests"
  
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.telemetry_lambda_package.key
  
  runtime = var.lambda_runtime
  handler = "telemetry.lambda_handler"
  
  role = aws_iam_role.lambda_role.arn
  
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
  
  # Enable X-Ray tracing if specified
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }
  
  # Environment variables
  environment {
    variables = {
      TELEMETRY_TABLE = aws_dynamodb_table.telemetry.name
      DRIVER_TABLE    = aws_dynamodb_table.drivers.name
      LAP_TABLE       = aws_dynamodb_table.laps.name
      STAGE           = var.stage
    }
  }
  
  # Provisioned concurrency if enabled
  dynamic "provisioned_concurrency_config" {
    for_each = var.provisioned_concurrency > 0 ? [1] : []
    content {
      provisioned_concurrent_executions = var.provisioned_concurrency
    }
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-telemetry-lambda-${var.stage}"
    Environment = var.stage
  })
}

# Driver data Lambda function
resource "aws_lambda_function" "driver_data" {
  function_name = "${local.service_name}-driver-data-${var.stage}"
  description   = "Lambda function to handle driver data requests"
  
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.driver_data_lambda_package.key
  
  runtime = var.lambda_runtime
  handler = "driver_data.lambda_handler"
  
  role = aws_iam_role.lambda_role.arn
  
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
  
  # Enable X-Ray tracing if specified
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }
  
  # Environment variables
  environment {
    variables = {
      DRIVER_TABLE = aws_dynamodb_table.drivers.name
      STAGE        = var.stage
    }
  }
  
  # Provisioned concurrency if enabled
  dynamic "provisioned_concurrency_config" {
    for_each = var.provisioned_concurrency > 0 ? [1] : []
    content {
      provisioned_concurrent_executions = var.provisioned_concurrency
    }
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-driver-data-lambda-${var.stage}"
    Environment = var.stage
  })
}

# Race data Lambda function
resource "aws_lambda_function" "race_data" {
  function_name = "${local.service_name}-race-data-${var.stage}"
  description   = "Lambda function to handle race data requests"
  
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.race_data_lambda_package.key
  
  runtime = var.lambda_runtime
  handler = "race_data.lambda_handler"
  
  role = aws_iam_role.lambda_role.arn
  
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
  
  # Enable X-Ray tracing if specified
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }
  
  # Environment variables
  environment {
    variables = {
      LAP_TABLE     = aws_dynamodb_table.laps.name
      DRIVER_TABLE  = aws_dynamodb_table.drivers.name
      STAGE         = var.stage
    }
  }
  
  # Provisioned concurrency if enabled
  dynamic "provisioned_concurrency_config" {
    for_each = var.provisioned_concurrency > 0 ? [1] : []
    content {
      provisioned_concurrent_executions = var.provisioned_concurrency
    }
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-race-data-lambda-${var.stage}"
    Environment = var.stage
  })
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "api_gateway_telemetry" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telemetry.function_name
  principal     = "apigateway.amazonaws.com"
  
  # The source ARN for the API Gateway REST API
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "api_gateway_driver_data" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.driver_data.function_name
  principal     = "apigateway.amazonaws.com"
  
  # The source ARN for the API Gateway REST API
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "api_gateway_race_data" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.race_data.function_name
  principal     = "apigateway.amazonaws.com"
  
  # The source ARN for the API Gateway REST API
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

# CloudWatch Log Groups for Lambda functions
resource "aws_cloudwatch_log_group" "telemetry_logs" {
  name              = "/aws/lambda/${aws_lambda_function.telemetry.function_name}"
  retention_in_days = 30
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-telemetry-logs-${var.stage}"
    Environment = var.stage
  })
}

resource "aws_cloudwatch_log_group" "driver_data_logs" {
  name              = "/aws/lambda/${aws_lambda_function.driver_data.function_name}"
  retention_in_days = 30
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-driver-data-logs-${var.stage}"
    Environment = var.stage
  })
}

resource "aws_cloudwatch_log_group" "race_data_logs" {
  name              = "/aws/lambda/${aws_lambda_function.race_data.function_name}"
  retention_in_days = 30
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-race-data-logs-${var.stage}"
    Environment = var.stage
  })
}

# Lambda warm-up configuration (optional)
resource "aws_cloudwatch_event_rule" "lambda_warm_up" {
  count = var.enable_lambda_warm_up ? 1 : 0
  
  name                = "${local.service_name}-lambda-warm-up-${var.stage}"
  description         = "Keep Lambda functions warm by periodic invocation"
  schedule_expression = "rate(5 minutes)"
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-lambda-warm-up-${var.stage}"
    Environment = var.stage
  })
}

resource "aws_cloudwatch_event_target" "telemetry_warm_up" {
  count = var.enable_lambda_warm_up ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.lambda_warm_up[0].name
  target_id = "TelemetryLambda"
  arn       = aws_lambda_function.telemetry.arn
  
  input = jsonencode({
    source = "warm-up",
    detail = {
      action = "warm-up"
    }
  })
}

resource "aws_cloudwatch_event_target" "driver_data_warm_up" {
  count = var.enable_lambda_warm_up ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.lambda_warm_up[0].name
  target_id = "DriverDataLambda"
  arn       = aws_lambda_function.driver_data.arn
  
  input = jsonencode({
    source = "warm-up",
    detail = {
      action = "warm-up"
    }
  })
}

resource "aws_cloudwatch_event_target" "race_data_warm_up" {
  count = var.enable_lambda_warm_up ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.lambda_warm_up[0].name
  target_id = "RaceDataLambda"
  arn       = aws_lambda_function.race_data.arn
  
  input = jsonencode({
    source = "warm-up",
    detail = {
      action = "warm-up"
    }
  })
}

# Lambda permission for CloudWatch Events (warm-up)
resource "aws_lambda_permission" "allow_cloudwatch_telemetry" {
  count = var.enable_lambda_warm_up ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telemetry.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_warm_up[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_driver_data" {
  count = var.enable_lambda_warm_up ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.driver_data.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_warm_up[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_race_data" {
  count = var.enable_lambda_warm_up ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.race_data.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_warm_up[0].arn
}

# CloudWatch alarms for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.service_name}-lambda-errors-${var.stage}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function error rate is too high"
  
  dimensions = {
    FunctionName = aws_lambda_function.telemetry.function_name
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-lambda-alarm-${var.stage}"
    Environment = var.stage
  })
}

# CloudWatch dashboard for Lambda functions
resource "aws_cloudwatch_dashboard" "lambda_dashboard" {
  dashboard_name = "${local.service_name}-lambda-dashboard-${var.stage}"
  
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
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.telemetry.function_name],
            [".", ".", ".", aws_lambda_function.driver_data.function_name],
            [".", ".", ".", aws_lambda_function.race_data.function_name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "Lambda Function Invocations",
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
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.telemetry.function_name],
            [".", ".", ".", aws_lambda_function.driver_data.function_name],
            [".", ".", ".", aws_lambda_function.race_data.function_name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "Lambda Function Duration",
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
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.telemetry.function_name],
            [".", ".", ".", aws_lambda_function.driver_data.function_name],
            [".", ".", ".", aws_lambda_function.race_data.function_name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "Lambda Function Errors",
          stat     = "Sum",
          period   = 300
        }
      }
    ]
  })
}

# Outputs for Lambda functions
output "telemetry_lambda_name" {
  description = "Name of the Telemetry Lambda function"
  value       = aws_lambda_function.telemetry.function_name
}

output "driver_data_lambda_name" {
  description = "Name of the Driver Data Lambda function"
  value       = aws_lambda_function.driver_data.function_name
}

output "race_data_lambda_name" {
  description = "Name of the Race Data Lambda function"
  value       = aws_lambda_function.race_data.function_name
}