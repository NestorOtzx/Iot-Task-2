# Empaqueta el codigo Python de la Lambda que recibe eventos criticos desde IoT Core.
# Terraform genera este ZIP localmente y lo sube al crear o actualizar la funcion.
data "archive_file" "lambda_alerta_zip" {
  type        = "zip"
  source_file = "${path.root}/src/lambda_alerta/lambda_function.py"
  output_path = "${path.module}/lambda_alerta.zip"
}

# Empaqueta el codigo Python de la Lambda que consume mensajes desde SQS.
# Separar los ZIPs permite actualizar cada funcion de manera independiente.
data "archive_file" "lambda_cloudwatch_zip" {
  type        = "zip"
  source_file = "${path.root}/src/lambda_cloudwatch/lambda_function.py"
  output_path = "${path.module}/lambda_cloudwatch.zip"
}

# Empaqueta la Lambda que reemplaza la escritura directa de IoT a DynamoDB.
# Esta funcion guarda cada evento y elimina los registros antiguos para dejar maximo 10 por sensor.
data "archive_file" "dynamodb_retention_writer_zip" {
  type        = "zip"
  source_file = "${path.root}/src/dynamodb_retention_writer/lambda_function.py"
  output_path = "${path.module}/dynamodb_retention_writer.zip"
}

# Cola SQS que desacopla la alerta recibida por IoT del procesamiento en CloudWatch.
# Si la Lambda de CloudWatch falla temporalmente, SQS conserva el mensaje para reintentos.
resource "aws_sqs_queue" "alert_queue" {
  name                       = "${var.project_name}-${var.environment}-iot-alerts"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Log group dedicado para los eventos de urgencia generados por la segunda Lambda.
# Este log group separa las alertas de negocio de los logs tecnicos propios de Lambda.
resource "aws_cloudwatch_log_group" "emergency_alerts" {
  name              = "/iot/${var.project_name}/${var.environment}/emergency-alerts"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Log stream fijo donde la Lambda consumidora escribe los mensajes de urgencia.
# Mantener un stream conocido facilita encontrar las alertas durante las pruebas del laboratorio.
resource "aws_cloudwatch_log_stream" "emergency_alerts" {
  name           = "sqs-alert-consumer"
  log_group_name = aws_cloudwatch_log_group.emergency_alerts.name
}

# Primera Lambda de la rama: recibe el payload filtrado por la regla de IoT Core.
# Su responsabilidad es normalizar el evento critico y enviarlo a la cola SQS.
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

# Segunda Lambda de la rama: se activa con mensajes nuevos en SQS.
# Lee cada alerta y la registra en el log group dedicado de CloudWatch Logs.
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

# Trigger administrado por Lambda para leer la cola SQS en lotes pequenos.
# batch_size = 1 hace que cada alerta sea facil de rastrear durante las pruebas.
resource "aws_lambda_event_source_mapping" "alert_queue_to_cloudwatch" {
  event_source_arn = aws_sqs_queue.alert_queue.arn
  function_name    = aws_lambda_function.lambda_cloudwatch.arn
  batch_size       = 1
  enabled          = true
}

# Lambda que recibe todos los eventos de sensores desde IoT Core.
# Escribe el evento en DynamoDB y aplica la regla de negocio: maximo 10 registros por device_id.
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
