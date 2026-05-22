resource "aws_dynamodb_table" "sensor_data" {
  # Tabla de hot data con historial corto por sensor.
  # device_id agrupa los eventos y timestamp permite ordenar los ultimos registros.
  name         = "SensorData-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device_id"
  range_key    = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
