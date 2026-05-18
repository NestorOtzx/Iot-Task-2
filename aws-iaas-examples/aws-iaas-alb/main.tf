# 1. Crear las 3 instancias EC2
resource "aws_instance" "web" {
  count             = length(var.subnets) # Ciclo: va de 0 a 2 (crea 3 maquinas)
  ami               = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = var.subnets[count.index]

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Script que se ejecuta en el primer arranque
  user_data = file("${path.module}/script.sh")

  tags = {
    Name = "WebServer-APP-${count.index + 1}"
  }
}

# 2. Crear el Target Group para el ALB
resource "aws_lb_target_group" "tg" {
  name     = "proyecto-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 3. Adjuntar las 3 instancias al Target Group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  count            = length(var.subnets)
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# 4. Crear el Load Balancer (ALB)
resource "aws_lb" "alb" {
  name               = "proyecto-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnets

  tags = {
    Name = "Web-ALB"
  }
}

# 5. Listener para el ALB (atiende el puerto 80)
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
