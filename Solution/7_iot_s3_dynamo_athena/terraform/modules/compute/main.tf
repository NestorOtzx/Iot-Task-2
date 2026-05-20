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

# Empaqueta la Lambda que procesa objetos nuevos de S3 hacia PostgreSQL.
# Este source_dir incluye lambda_function.py y las dependencias puras instaladas con pip, como pg8000.
data "archive_file" "s3_to_postgres_zip" {
  type        = "zip"
  source_dir  = "${path.root}/src/s3_to_postgres"
  output_path = "${path.module}/s3_to_postgres.zip"
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

# Lambda de mantenimiento aciclico: se ejecuta cuando llega un JSON nuevo al bucket historico.
# Lee el objeto de S3, lo inserta en RDS PostgreSQL y conserva solo los ultimos 10 eventos por sensor.
resource "aws_lambda_function" "s3_to_postgres" {
  function_name    = "${var.project_name}-${var.environment}-s3-to-postgres"
  role             = var.lab_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.s3_to_postgres_zip.output_path
  source_code_hash = data.archive_file.s3_to_postgres_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      PG_HOST     = var.postgres_endpoint
      PG_PORT     = tostring(var.postgres_port)
      PG_DATABASE = var.postgres_db_name
      PG_USER     = var.postgres_username
      PG_PASSWORD = var.postgres_password
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Permiso basado en recurso para que S3 pueda invocar la Lambda al crear objetos.
# Sin este permiso, la notificacion del bucket se configura pero S3 no puede ejecutar la funcion.
resource "aws_lambda_permission" "allow_s3_to_invoke_postgres_lambda" {
  statement_id  = "AllowExecutionFromS3SensorBucket${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_postgres.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.sensor_bucket_name}"
}

# Notificacion del bucket historico de sensores.
# Filtramos por el prefijo data/ porque las reglas IoT guardan ahi los JSON particionados.
resource "aws_s3_bucket_notification" "sensor_data_to_postgres" {
  bucket = var.sensor_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_postgres.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "data/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3_to_invoke_postgres_lambda]
}

# VPC default del laboratorio para ejecutar la API en ECS Fargate.
# Reutilizamos la red administrada por AWS para no agregar todavia un modulo networking propio.
data "aws_vpc" "default" {
  default = true
}

# Subnets default donde ECS puede colocar tareas Fargate con IP publica.
# Al usar assign_public_ip, la API puede salir hacia DynamoDB, RDS y Athena sin NAT Gateway.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Repositorio ECR donde se publicara la imagen Docker de FastAPI.
# Terraform crea el destino, pero la construccion y push de la imagen se hacen fuera de Terraform.
resource "aws_ecr_repository" "api" {
  name         = "${var.project_name}-${var.environment}-sensor-api"
  force_delete = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Cluster ECS para alojar la API REST unificada.
# Fargate evita administrar instancias EC2 y encaja bien con el alcance del laboratorio.
resource "aws_ecs_cluster" "api" {
  name = "${var.project_name}-${var.environment}-api-cluster"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Log group tecnico de la API en ECS.
# Uvicorn y FastAPI enviaran stdout/stderr a este grupo mediante awslogs.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}/${var.environment}/sensor-api"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security Group publico para exponer la API en el puerto 8000.
# Es deliberadamente abierto para pruebas del laboratorio; en produccion convendria usar ALB y rangos restringidos.
resource "aws_security_group" "api" {
  name        = "${var.project_name}-${var.environment}-api-sg"
  description = "Permite acceso HTTP a la API FastAPI"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "FastAPI"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida general"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Task definition de Fargate para la API.
# Usa la imagen :latest del repositorio ECR y recibe por variables los nombres de DynamoDB, RDS y Athena.
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-${var.environment}-sensor-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "sensor-api"
      image     = "${aws_ecr_repository.api.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "AWS_REGION", value = var.region },
        { name = "SENSOR_TABLE_NAME", value = var.sensor_table_name },
        { name = "ATHENA_DATABASE", value = var.athena_database_name },
        { name = "ATHENA_TABLE", value = var.athena_table_name },
        { name = "ATHENA_RESULTS_BUCKET", value = var.athena_results_bucket_name },
        { name = "PG_HOST", value = var.postgres_endpoint },
        { name = "PG_PORT", value = tostring(var.postgres_port) },
        { name = "PG_DATABASE", value = var.postgres_db_name },
        { name = "PG_USER", value = var.postgres_username },
        { name = "PG_PASSWORD", value = var.postgres_password }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "api"
        }
      }
    }
  ])

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Servicio ECS que mantiene la API disponible en Fargate.
# desired_count queda configurable; por defecto 0 para permitir aplicar Terraform antes de subir la imagen a ECR.
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-${var.environment}-sensor-api"
  cluster         = aws_ecs_cluster.api.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
