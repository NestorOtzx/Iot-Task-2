provider "aws" {
  region = "us-east-1"
}

# --- Recursos Globales / Compartidos ---

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

data "aws_caller_identity" "current" {}


# 1. SOLUCIÓN: SQS + LAMBDA

resource "aws_sqs_queue" "lambda_queue" {
  name                      = "my-lambda-queue"
  delay_seconds             = 0
  max_message_size          = 262144 #256KB, límite máximo absoluto que permite AWS SQS.
  message_retention_seconds = 86400 # cuánto tiempo SQS guardará un mensaje en la cola 
                                    # si ningún consumidor lo lee y lo elimina (1 dia en este caso).
                                    # el mínimo es 60 segundos y el máximo es 14 días.
  receive_wait_time_seconds = 0 # Configura si la cola usa Short Polling (encuestas cortas) 
                                # o Long Polling (encuestas largas) por defecto.
                                # 0 = Short Polling, >0 = Long Polling (en este caso 0)
                                # Short Polling: cuando un consumidor pregunta "¿hay mensajes?", 
                                # SQS responde inmediatamente; si no hay mensajes, responde vacío 
                                # al instante.
                                # Long Polling: cuando un consumidor pregunta "¿hay mensajes?", 
                                # SQS espera hasta que haya mensajes o hasta que expire el 
                                # receive_wait_time_seconds antes de responder.
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dummy_lambda.zip"

  source {
    content  = "def lambda_handler(event, context): pass"
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "sqs_processor" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "SqsProcessorLambda"
  role          = data.aws_iam_role.lab_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.lambda_queue.url
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

# Es como un supervisor para la cola. 
# Revisa si hay mensajes en la cola y llama a la función lambda.
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
  event_source_arn = aws_sqs_queue.lambda_queue.arn
  function_name    = aws_lambda_function.sqs_processor.arn
  batch_size       = 10 # Si hay 10 mensajes en cola el supervisor llama a la funcion lambda 1 vez. 
                        # por lo que la función lambda recibirá 10 mensajes en el parámetro 'event'.
  enabled          = true
}


# 2. SOLUCIÓN: SQS + ECS

resource "aws_sqs_queue" "ecs_queue" {
  name                      = "my-ecs-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 0
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/sqs-consumer"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "sqs_cluster" {
  name = "sqs-consumer-cluster"
}

resource "aws_ecs_task_definition" "sqs_consumer_task" {
  family                   = "sqs-consumer-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "sqs-consumer-container"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/sqs-consumer-repo:latest"
      essential = true
      
      environment = [
        {
          name  = "QUEUE_URL"
          value = aws_sqs_queue.ecs_queue.url
        },
        {
          name  = "AWS_REGION"
          value = "us-east-1"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "sqs_consumer_service" {
  name            = "sqs-consumer-service"
  cluster         = aws_ecs_cluster.sqs_cluster.id
  task_definition = aws_ecs_task_definition.sqs_consumer_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
  }
}

# --- Outputs ---

output "lambda_queue_url" {
  value = aws_sqs_queue.lambda_queue.url
}

output "ecs_queue_url" {
  value = aws_sqs_queue.ecs_queue.url
}
