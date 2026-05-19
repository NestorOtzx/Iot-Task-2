resource "aws_dynamodb_table" "sensor_data" {
  # Añadimos el sufijo del entorno para evitar conflictos si hay varios ambientes
  name           = "SensorData-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  
  # Al tener SOLO un Partition Key (hash_key) y NO tener Sort Key (range_key),
  # cada vez que llegue un evento con el mismo device_id, DynamoDB
  # simplemente sobrescribirá el registro existente. ¡Perfecto para "Hot Data"!
  hash_key       = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
