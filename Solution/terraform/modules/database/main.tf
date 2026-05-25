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
