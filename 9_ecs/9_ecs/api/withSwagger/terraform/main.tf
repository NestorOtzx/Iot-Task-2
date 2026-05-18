# Obtener la cuenta de AWS y región actual
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# El rol de Learner Lab "LabRole"
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# 1. Repositorio ECR (creado por fuera de Terraform)
data "aws_ecr_repository" "api_repo" {
  name = var.ecr_repo_name
}

# 2. Cluster ECS
resource "aws_ecs_cluster" "api_cluster" {
  name = "swagger-fastapi-cluster"
}

# 3. Application Load Balancer
resource "aws_lb" "api_alb" {
  name               = "swagger-fastapi-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "api_tg" {
  name        = "swagger-fastapi-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
    path                = "/health"
    interval            = 30
  }
}

resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

# 4. ECS Task Definition (Fargate)
resource "aws_ecs_task_definition" "api_task" {
  family                   = "swagger-fastapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name  = "swagger-fastapi-container"
      image = "${data.aws_ecr_repository.api_repo.repository_url}:latest"
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/swagger-fastapi"
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# 5. ECS Service
resource "aws_ecs_service" "api_service" {
  name            = "swagger-fastapi-service"
  cluster         = aws_ecs_cluster.api_cluster.id
  task_definition = aws_ecs_task_definition.api_task.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_tg.arn
    container_name   = "swagger-fastapi-container"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.api_listener]
}

# 6. API Gateway (REST API - v1) importado desde Swagger
resource "aws_api_gateway_rest_api" "swagger_api" {
  name = "fastapi-swagger-api"
  
  # Usamos templatefile para inyectar el DNS del Load Balancer en el JSON generado
  body = templatefile("${path.module}/openapi_with_extensions.json", {
    alb_dns_name = aws_lb.api_alb.dns_name
  })
}

# Despliegue de la API
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.swagger_api.id

  # Al cambiar el body, se forzará un nuevo despliegue
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.swagger_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage (Entorno de la API, e.g., prod)
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.swagger_api.id
  stage_name    = "prod"
}
