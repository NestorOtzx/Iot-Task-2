# Empaqueta Lambda de alertas.
data "archive_file" "lambda_alerta_zip" {
  type        = "zip"
  source_file = "${path.root}/src/lambda_alerta/lambda_function.py"
  output_path = "${path.module}/lambda_alerta.zip"
}

# Empaqueta Lambda de CloudWatch.
data "archive_file" "lambda_cloudwatch_zip" {
  type        = "zip"
  source_file = "${path.root}/src/lambda_cloudwatch/lambda_function.py"
  output_path = "${path.module}/lambda_cloudwatch.zip"
}

# Empaqueta Lambda de DynamoDB.
data "archive_file" "dynamodb_retention_writer_zip" {
  type        = "zip"
  source_file = "${path.root}/src/dynamodb_retention_writer/lambda_function.py"
  output_path = "${path.module}/dynamodb_retention_writer.zip"
}

# Ruta de Lambda historica.
locals {
  s3_to_rds_source_dir = abspath("${path.root}/src/s3_to_rds")
}

# Empaqueta Lambda S3 a RDS.
data "archive_file" "s3_to_rds_zip" {
  type        = "zip"
  source_dir  = local.s3_to_rds_source_dir
  output_path = "${path.module}/s3_to_rds.zip"
}

# Cola SQS de alertas.
resource "aws_sqs_queue" "alert_queue" {
  name                       = "${var.project_name}-${var.environment}-iot-alerts"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Log group de urgencias.
resource "aws_cloudwatch_log_group" "emergency_alerts" {
  name              = "/iot/${var.project_name}/${var.environment}/emergency-alerts"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Log stream de urgencias.
resource "aws_cloudwatch_log_stream" "emergency_alerts" {
  name           = "sqs-alert-consumer"
  log_group_name = aws_cloudwatch_log_group.emergency_alerts.name
}

# Lambda de alerta IoT.
resource "aws_lambda_function" "lambda_alerta" {
  function_name    = "${var.project_name}-${var.environment}-lambda-alerta"
  role             = var.lab_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_alerta_zip.output_path
  source_code_hash = data.archive_file.lambda_alerta_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      ALERT_QUEUE_URL = aws_sqs_queue.alert_queue.url
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda consumidora SQS.
resource "aws_lambda_function" "lambda_cloudwatch" {
  function_name                  = "${var.project_name}-${var.environment}-lambda-cloudwatch"
  role                           = var.lab_role_arn
  handler                        = "lambda_function.lambda_handler"
  runtime                        = "python3.12"
  filename                       = data.archive_file.lambda_cloudwatch_zip.output_path
  source_code_hash               = data.archive_file.lambda_cloudwatch_zip.output_base64sha256
  timeout                        = 15
  reserved_concurrent_executions = 1

  environment {
    variables = {
      LOG_GROUP_NAME  = aws_cloudwatch_log_group.emergency_alerts.name
      LOG_STREAM_NAME = aws_cloudwatch_log_stream.emergency_alerts.name
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Trigger SQS hacia Lambda.
resource "aws_lambda_event_source_mapping" "alert_queue_to_cloudwatch" {
  event_source_arn = aws_sqs_queue.alert_queue.arn
  function_name    = aws_lambda_function.lambda_cloudwatch.arn
  batch_size       = 1
  enabled          = true
}

# Lambda de datos recientes.
resource "aws_lambda_function" "dynamodb_retention_writer" {
  function_name                  = "${var.project_name}-${var.environment}-dynamodb-retention-writer"
  role                           = var.lab_role_arn
  handler                        = "lambda_function.lambda_handler"
  runtime                        = "python3.12"
  filename                       = data.archive_file.dynamodb_retention_writer_zip.output_path
  source_code_hash               = data.archive_file.dynamodb_retention_writer_zip.output_base64sha256
  timeout                        = 10
  reserved_concurrent_executions = 1

  environment {
    variables = {
      SENSOR_TABLE_NAME     = var.sensor_table_name
      MAX_EVENTS_PER_SENSOR = "10"
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lambda historica por S3.
resource "aws_lambda_function" "s3_to_rds" {
  function_name    = "${var.project_name}-${var.environment}-s3-to-rds-history"
  role             = var.lab_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.s3_to_rds_zip.output_path
  source_code_hash = data.archive_file.s3_to_rds_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      SENSOR_TABLE_NAME = var.sensor_table_name
      RDS_HOST          = var.rds_host
      RDS_PORT          = tostring(var.rds_port)
      RDS_DB_NAME       = var.rds_db_name
      RDS_USERNAME      = var.rds_username
      RDS_PASSWORD      = var.rds_password
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Permiso S3 hacia Lambda.
resource "aws_lambda_permission" "allow_s3_to_rds" {
  statement_id  = "AllowExecutionFromS3History${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_rds.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.sensor_bucket_name}"
}

# Trigger S3 ObjectCreated.
resource "aws_s3_bucket_notification" "sensor_data_to_rds" {
  bucket = var.sensor_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_rds.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3_to_rds]
}
