# 1. RabbitMQ EC2
resource "aws_instance" "rabbitmq" {
  ami               = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = var.subnet_id
  vpc_security_group_ids = [aws_security_group.rabbitmq_sg.id]
  user_data         = file("${path.module}/install_rabbitmq.sh")

  tags = {
    Name    = "RabbitMQ-Server"
    Role    = "MessageBroker"
  }
}

# 2. Docker / API Rest EC2
resource "aws_instance" "api_server" {
  ami               = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = var.subnet_id
  vpc_security_group_ids = [aws_security_group.api_sg.id]
  user_data         = file("${path.module}/install_api.sh")

  tags = {
    Name    = "Docker-API-Server"
    Role    = "BackendAPI"
  }
}

# 3. Worker EC2
resource "aws_instance" "worker" {
  ami               = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = var.subnet_id
  vpc_security_group_ids = [aws_security_group.worker_sg.id]
  user_data         = file("${path.module}/install_worker.sh")

  tags = {
    Name    = "Worker-Server"
    Role    = "AsyncWorker"
  }
}

# 4. PostgreSQL EC2
resource "aws_instance" "postgres" {
  ami               = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = var.subnet_id
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  user_data         = file("${path.module}/install_postgres.sh")

  tags = {
    Name    = "Postgres-Server"
    Role    = "Database"
  }
}

# 5. MongoDB EC2
resource "aws_instance" "mongodb" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]
  user_data              = file("${path.module}/install_mongodb.sh")

  tags = {
    Name = "MongoDB-Server"
    Role = "NoSQLDatabase"
  }
}

# ==========================================
# AWS Systems Manager Parameter Store
# ==========================================

resource "aws_ssm_parameter" "rabbitmq_ip" {
  name  = "/message-queue/dev/rabbitmq/public_ip"
  type  = "String"
  value = aws_instance.rabbitmq.public_ip
  description = "Public IP for RabbitMQ Server"
}

resource "aws_ssm_parameter" "api_ip" {
  name  = "/message-queue/dev/api/public_ip"
  type  = "String"
  value = aws_instance.api_server.public_ip
  description = "Public IP for Docker API Server"
}

resource "aws_ssm_parameter" "worker_ip" {
  name  = "/message-queue/dev/worker/public_ip"
  type  = "String"
  value = aws_instance.worker.public_ip
  description = "Public IP for Async Worker Server"
}

resource "aws_ssm_parameter" "postgres_ip" {
  name        = "/message-queue/dev/postgres/public_ip"
  type        = "String"
  value       = aws_instance.postgres.public_ip
  description = "Public IP for PostgreSQL Server"
}

resource "aws_ssm_parameter" "mongodb_ip" {
  name        = "/message-queue/dev/mongodb/public_ip"
  type        = "String"
  value       = aws_instance.mongodb.public_ip
  description = "Public IP for MongoDB Server"
}
