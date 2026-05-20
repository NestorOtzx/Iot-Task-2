resource "aws_dynamodb_table" "sensor_data" {
  # Añadimos el sufijo del entorno para evitar conflictos si hay varios ambientes
  name         = "SensorData-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  # Al tener SOLO un Partition Key (hash_key) y NO tener Sort Key (range_key),
  # cada vez que llegue un evento con el mismo device_id, DynamoDB
  # simplemente sobrescribirá el registro existente. ¡Perfecto para "Hot Data"!
  hash_key = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# VPC default del Learner Lab.
# La usamos para mantener el laboratorio simple y no introducir aun una red custom.
data "aws_vpc" "default" {
  default = true
}

# Subnets disponibles dentro de la VPC default.
# RDS necesita un DB subnet group con al menos dos subnets para poder desplegarse.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Password aleatorio para PostgreSQL.
# Se marca como sensible en los outputs para no imprimirlo accidentalmente en consola.
resource "random_password" "rds_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Security Group de RDS.
# Para este laboratorio se permite acceso TCP/5432 desde cualquier origen para que Lambda y la API local puedan conectarse.
resource "aws_security_group" "rds_postgres" {
  name        = "${var.project_name}-${var.environment}-postgres-sg"
  description = "Permite acceso PostgreSQL para metadatos IoT"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
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

# DB subnet group para RDS PostgreSQL.
# Agrupa las subnets default donde AWS puede ubicar la instancia administrada.
resource "aws_db_subnet_group" "postgres" {
  name       = "${var.project_name}-${var.environment}-postgres-subnets"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Base relacional PostgreSQL para metadatos y ciclo corto.
# db.t3.micro cumple el requisito del laboratorio y publicly_accessible permite pruebas desde Lambda/API local.
resource "aws_db_instance" "postgres_metadata" {
  identifier             = "${var.project_name}-${var.environment}-metadata"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = var.rds_instance_class
  allocated_storage      = 20
  db_name                = var.rds_db_name
  username               = var.rds_username
  password               = random_password.rds_password.result
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds_postgres.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
