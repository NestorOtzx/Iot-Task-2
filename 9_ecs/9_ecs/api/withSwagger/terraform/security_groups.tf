# Obtenemos la VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# Obtenemos las subredes de la VPC por defecto
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# SG para el Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "swagger-alb-sg"
  description = "Permite trafico HTTP entrante al ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG para las tareas de ECS (Fargate)
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "swagger-ecs-tasks-sg"
  description = "Permite trafico entrante desde el ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
