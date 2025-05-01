# DynamoDB configuration for the F1 Telemetry WebApp

# Telemetry data table
resource "aws_dynamodb_table" "telemetry" {
  name           = "${var.telemetry_table_name}-${var.stage}"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"  # String type for composite key
  }
  
  attribute {
    name = "session_uid"
    type = "S"  # String type for session ID
  }
  
  attribute {
    name = "driver_id"
    type = "N"  # Number type for driver ID
  }
  
  # Global Secondary Index for querying by session_uid
  global_secondary_index {
    name               = "SessionIndex"
    hash_key           = "session_uid"
    projection_type    = "ALL"
    read_capacity      = var.read_capacity
    write_capacity     = var.write_capacity
  }
  
  # Global Secondary Index for querying by driver_id
  global_secondary_index {
    name               = "DriverIndex"
    hash_key           = "driver_id"
    projection_type    = "ALL"
    read_capacity      = var.read_capacity
    write_capacity     = var.write_capacity
  }
  
  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-telemetry-${var.stage}"
    Environment = var.stage
  })
}

# Driver data table
resource "aws_dynamodb_table" "drivers" {
  name           = "${var.driver_table_name}-${var.stage}"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"  # String type for composite key
  }
  
  attribute {
    name = "session_uid"
    type = "S"  # String type for session ID
  }
  
  attribute {
    name = "driver_id"
    type = "N"  # Number type for driver ID
  }
  
  # Global Secondary Index for querying by session_uid
  global_secondary_index {
    name               = "SessionIndex"
    hash_key           = "session_uid"
    projection_type    = "ALL"
    read_capacity      = var.read_capacity
    write_capacity     = var.write_capacity
  }
  
  # Global Secondary Index for querying by driver_id
  global_secondary_index {
    name               = "DriverIndex"
    hash_key           = "driver_id"
    projection_type    = "ALL"
    read_capacity      = var.read_capacity
    write_capacity     = var.write_capacity
  }
  
  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-drivers-${var.stage}"
    Environment = var.stage
  })
}

# Lap data table
resource "aws_dynamodb_table" "laps" {
  name           = "${var.lap_table_name}-${var.stage}"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"  # String type for composite key
  }
  
  attribute {
    name = "session_uid"
    type = "S"  # String type for session ID
  }
  
  attribute {
    name = "driver_id"
    type = "N"  # Number type for driver ID
  }
  
  attribute {
    name = "lap_number"
    type = "N"  # Number type for lap number
  }
  
  # Global Secondary Index for querying by session_uid
  global_secondary_index {
    name               = "SessionIndex"
    hash_key           = "session_uid"
    projection_type    = "ALL"
    read_capacity      = var.read_capacity
    write_capacity     = var.write_capacity
  }
  
  # Global Secondary Index for querying by driver_id
  global_secondary_index {
    name               = "DriverIndex"
    hash_key           = "driver_id"
    projection_type    = "ALL"
    read_capacity      = var.read_capacity
    write_capacity     = var.write_capacity
  }
  
  # Global Secondary Index for querying by lap_number
  global_secondary_index {
    name               = "LapIndex"
    hash_key           = "lap_number"
    projection_type    = "ALL"
    read_capacity      = var.read_capacity
    write_capacity     = var.write_capacity
  }
  
  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-laps-${var.stage}"
    Environment = var.stage
  })
}

# CloudWatch alarms for DynamoDB throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  alarm_name          = "${local.service_name}-dynamodb-read-throttles-${var.stage}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "SampleCount"
  threshold           = 1
  alarm_description   = "DynamoDB read throttle events occurred"
  
  dimensions = {
    TableName = aws_dynamodb_table.telemetry.name
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-dynamodb-alarm-${var.stage}"
    Environment = var.stage
  })
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttles" {
  alarm_name          = "${local.service_name}-dynamodb-write-throttles-${var.stage}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "SampleCount"
  threshold           = 1
  alarm_description   = "DynamoDB write throttle events occurred"
  
  dimensions = {
    TableName = aws_dynamodb_table.telemetry.name
  }
  
  tags = merge(var.tags, {
    Name        = "${local.service_name}-dynamodb-alarm-${var.stage}"
    Environment = var.stage
  })
}

# CloudWatch dashboard for DynamoDB tables
resource "aws_cloudwatch_dashboard" "dynamodb" {
  dashboard_name = "${local.service_name}-dynamodb-dashboard-${var.stage}"
  
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
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.telemetry.name],
            [".", "ConsumedWriteCapacityUnits", ".", aws_dynamodb_table.telemetry.name],
            [".", "ConsumedReadCapacityUnits", ".", aws_dynamodb_table.drivers.name],
            [".", "ConsumedWriteCapacityUnits", ".", aws_dynamodb_table.drivers.name],
            [".", "ConsumedReadCapacityUnits", ".", aws_dynamodb_table.laps.name],
            [".", "ConsumedWriteCapacityUnits", ".", aws_dynamodb_table.laps.name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "DynamoDB Consumed Capacity Units",
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
            ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", aws_dynamodb_table.telemetry.name],
            [".", "WriteThrottleEvents", ".", aws_dynamodb_table.telemetry.name],
            [".", "ReadThrottleEvents", ".", aws_dynamodb_table.drivers.name],
            [".", "WriteThrottleEvents", ".", aws_dynamodb_table.drivers.name],
            [".", "ReadThrottleEvents", ".", aws_dynamodb_table.laps.name],
            [".", "WriteThrottleEvents", ".", aws_dynamodb_table.laps.name]
          ],
          view     = "timeSeries",
          stacked  = false,
          region   = var.region,
          title    = "DynamoDB Throttle Events",
          stat     = "Sum",
          period   = 300
        }
      }
    ]
  })
}