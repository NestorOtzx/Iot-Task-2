resource "aws_dynamodb_table" "sensor_data" {
  # Tabla DynamoDB para "Hot Data" del sistema IoT.
  # Se modela como una base clave-valor: un ítem por sensor, identificado por device_id.
  # Este diseño deja preparada la tabla para futuros endpoints como GET /sensors y POST /sensors.
  name         = "SensorData-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  # Clave de partición:
  # device_id es la única clave primaria. Cada sensor vive en un solo ítem y dentro del ítem
  # guardamos sus metadatos, su evento actual y una lista JSON con los últimos 10 eventos.
  hash_key = "device_id"

  # Atributo requerido por la hash_key definida arriba.
  attribute {
    name = "device_id"
    type = "S"
  }

  # Tags comunes para identificar recursos por ambiente y proyecto dentro de AWS.
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Sensores iniciales del laboratorio.
# La Lambda de ingesta NO crea sensores automaticamente; solo actualiza items existentes.
# Por eso sembramos los dos sensores definidos en docker-compose para que empiecen a recibir datos
# apenas se despliegue la infraestructura. Sensores nuevos deberan crearse luego por el flujo/API administrativa.
resource "aws_dynamodb_table_item" "default_sensors" {
  for_each = var.default_sensors

  table_name = aws_dynamodb_table.sensor_data.name
  hash_key   = aws_dynamodb_table.sensor_data.hash_key

  item = jsonencode({
    device_id = {
      S = each.key
    }
    sensor_type = {
      S = each.value.sensor_type
    }
    description = {
      S = each.value.description
    }
    status = {
      S = "registered"
    }
    created_by = {
      S = "terraform"
    }
    recent_events = {
      L = []
    }
  })

  # Terraform solo debe sembrar los sensores iniciales.
  # Despues de creados, la Lambda y la futura API actualizan campos como current_event,
  # last_value y recent_events; por eso ignoramos cambios del item completo para no pisar datos vivos.
  lifecycle {
    ignore_changes = [item]
  }
}

# VPC por defecto para RDS.
data "aws_vpc" "default" {
  default = true
}

# Subnets por defecto para RDS.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Password generado para PostgreSQL.
resource "random_password" "sensor_history" {
  length  = 20
  special = false
}

# Security group de RDS.
resource "aws_security_group" "sensor_history_db" {
  name        = "${var.project_name}-${var.environment}-sensor-history-db"
  description = "Permite acceso PostgreSQL a la base historica de sensores"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL para Lambda/API en el entorno de laboratorio"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.rds_allowed_cidr_blocks
  }

  egress {
    description = "Salida general requerida por el servicio administrado"
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

# Subnet group de RDS.
resource "aws_db_subnet_group" "sensor_history" {
  name       = "${var.project_name}-${var.environment}-sensor-history"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS PostgreSQL historico.
resource "aws_db_instance" "sensor_history" {
  identifier              = "${var.project_name}-${var.environment}-sensor-history"
  allocated_storage       = 20
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  db_name                 = "sensor_history"
  username                = "sensor_admin"
  password                = random_password.sensor_history.result
  db_subnet_group_name    = aws_db_subnet_group.sensor_history.name
  vpc_security_group_ids  = [aws_security_group.sensor_history_db.id]
  publicly_accessible     = true
  skip_final_snapshot     = true
  apply_immediately       = true
  backup_retention_period = 0

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
