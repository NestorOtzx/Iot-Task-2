provider "aws" {
  region = "us-east-1"
}

# Crear el Security Group en la VPC especificada
resource "aws_security_group" "web_sg" {
  name        = "opentofu_ec2_sg"
  description = "Alow SSH and HTTP inbound traffic"
  vpc_id      = "vpc-04182cca7699596a2"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

# Crear la instancia EC2
resource "aws_instance" "WebServer1" {
  ami               = "ami-02dfbd4ff395f2a1b" # Amazon Linux 2023 / u otra compatible en us-east-1
  instance_type     = "t3.micro"
  key_name          = "callanor2026_02"
  subnet_id         = "subnet-065e8b30cff0a381e"
  availability_zone = "us-east-1a"

  # Asignamos el Security Group creado arriba
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Le pasamos el script de inicialización
  user_data = file("${path.module}/script.sh")

  tags = {
    Name    = "WebServer1"
    Project = "Automatizacion"
  }
}

# Mostrar la IP Pública al finalizar
output "public_ip" {
  value       = aws_instance.WebServer1.public_ip
  description = "La IP pública de la instancia EC2"
}
