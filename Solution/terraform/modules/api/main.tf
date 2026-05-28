# VPC por defecto para API.
data "aws_vpc" "default" {
  default = true
}

# Subnets por defecto para API.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Repositorio ECR de API.
resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-${var.environment}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Cluster ECS de API.
resource "aws_ecs_cluster" "api" {
  name = "${var.project_name}-${var.environment}-api"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Logs de API.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}/${var.environment}/api"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security group del ALB.
resource "aws_security_group" "api_alb" {
  name        = "${var.project_name}-${var.environment}-api-alb"
  description = "Permite trafico HTTP publico hacia el ALB de FastAPI"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP publico para pruebas del laboratorio"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida hacia tareas ECS"
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

# Security group de tareas.
resource "aws_security_group" "api_tasks" {
  name        = "${var.project_name}-${var.environment}-api-tasks"
  description = "Permite trafico del ALB hacia FastAPI en ECS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "FastAPI desde el Load Balancer"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.api_alb.id]
  }

  egress {
    description = "Salida general para AWS APIs y PostgreSQL"
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

# ALB publico de API.
resource "aws_lb" "api" {
  name               = "${var.project_name}-${var.environment}-api"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.api_alb.id]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target group de API.
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-${var.environment}-api"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    enabled             = true
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener HTTP de API.
resource "aws_lb_listener" "api_http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

locals {
  api_image = "${aws_ecr_repository.api.repository_url}:${var.api_image_tag}"
}

# Task definition de FastAPI.
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-${var.environment}-fastapi"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.lab_role_arn
  task_role_arn            = var.lab_role_arn

  container_definitions = jsonencode([
    {
      name      = "fastapi"
      image     = local.api_image
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
        { name = "RDS_HOST", value = var.rds_host },
        { name = "RDS_PORT", value = tostring(var.rds_port) },
        { name = "RDS_DB_NAME", value = var.rds_db_name },
        { name = "RDS_USERNAME", value = var.rds_username },
        { name = "RDS_PASSWORD", value = var.rds_password }
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

# Servicio ECS de API.
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-${var.environment}-fastapi"
  cluster         = aws_ecs_cluster.api.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.api_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "fastapi"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.api_http]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
