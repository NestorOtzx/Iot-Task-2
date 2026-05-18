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
  name = "api-fastapi-cluster"
}

# 3. Application Load Balancer
resource "aws_lb" "api_alb" {
  name               = "api-fastapi-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "api_tg" {
  name        = "api-fastapi-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip" # Requerido para Fargate

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
  family                   = "api-fastapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  # Usamos el LabRole para la ejecución de la tarea
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name  = "api-fastapi-container"
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
          "awslogs-group"         = "/ecs/api-fastapi"
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
  name            = "api-fastapi-service"
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
    container_name   = "api-fastapi-container"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.api_listener]
}

# 6. API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "fastapi-http-api"
  protocol_type = "HTTP"
}

# Integración HTTP Proxy apuntando al DNS del ALB
resource "aws_apigatewayv2_integration" "alb_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id

  # Esto significa que el API Gateway no va a modificar el cuerpo de 
  # la petición ni la respuesta, simplemente tomará la petición HTTP 
  # del usuario tal cual como viene, se la pasará a otro destino, y 
  # devolverá la respuesta tal cual.
  integration_type = "HTTP_PROXY" 

  # indica hacia dónde mandar esa petición. En este caso, apunta directamente 
  # a la URL pública (DNS) de nuestro Load Balancer.
  integration_uri  = "http://${aws_lb.api_alb.dns_name}/{proxy}"

  # Acepta cualquier verbo HTTP (GET, POST, PUT, DELETE, etc).
  integration_method = "ANY"
  connection_type  = "INTERNET"
}

# Integración HTTP Proxy para el root (sin el {proxy})
resource "aws_apigatewayv2_integration" "alb_integration_root" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "HTTP_PROXY"
  integration_uri  = "http://${aws_lb.api_alb.dns_name}/"
  integration_method = "ANY"
  connection_type  = "INTERNET"
}

# Ruta global para que todo el tráfico vaya al ALB
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id

  # Esta es una ruta "comodín" o catch-all. Significa que atrapará 
  # cualquier verbo HTTP y cualquier ruta que venga después del dominio base
  # y se enviara al target, en este caso al ALB.
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
}

# Ruta especial para el root
resource "aws_apigatewayv2_route" "root_route" {
  api_id    = aws_apigatewayv2_api.http_api.id

  # El comodín /{proxy+} de la regla anterior requiere que exista algo después
  # del slash para activarse. Para que el usuario pueda visitar simplemente la
  # URL base (sin nada más) y ver el mensaje de "¡Hola desde FastAPI...!",
  # necesitamos atrapar explícitamente la ruta vacía ANY / y mandarla también
  # a nuestra integración.
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.alb_integration_root.id}"
}

resource "aws_apigatewayv2_stage" "dev_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "dev"
  auto_deploy = true
}
