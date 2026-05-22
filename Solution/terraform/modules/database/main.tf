resource "aws_dynamodb_table" "sensor_data" {
  # Tabla DynamoDB para "Hot Data" del sistema IoT.
  # A diferencia del diseño inicial, ahora no guardamos solo el último valor del sensor:
  # necesitamos conservar una ventana corta con los últimos 10 eventos por dispositivo.
  name         = "SensorData-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  # Clave de partición:
  # Agrupa todos los eventos que pertenecen al mismo sensor. Esto permite consultar
  # rápidamente el historial reciente de un dispositivo específico usando su device_id.
  hash_key = "device_id"

  # Clave de ordenamiento:
  # Permite que un mismo sensor tenga múltiples registros, uno por timestamp.
  # Gracias a esta sort key, la Lambda de retención puede consultar los eventos
  # ordenados por tiempo y borrar los más antiguos cuando haya más de 10.
  range_key = "timestamp"

  # Atributo requerido por la hash_key definida arriba.
  attribute {
    name = "device_id"
    type = "S"
  }

  # Atributo requerido por la range_key definida arriba.
  # Se guarda como string porque los sensores emiten timestamps ISO-8601, que ordenan bien lexicográficamente.
  attribute {
    name = "timestamp"
    type = "S"
  }

  # Tags comunes para identificar recursos por ambiente y proyecto dentro de AWS.
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
