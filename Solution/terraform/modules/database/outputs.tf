output "sensor_table_name" {
  value       = aws_dynamodb_table.sensor_data.name
  description = "Nombre de la tabla DynamoDB para los datos del sensor"
}

output "sensor_history_db_address" {
  value       = aws_db_instance.sensor_history.address
  description = "Host de PostgreSQL RDS usado para el historico de sensores."
}

output "sensor_history_db_port" {
  value       = aws_db_instance.sensor_history.port
  description = "Puerto de PostgreSQL RDS usado para el historico de sensores."
}

output "sensor_history_db_name" {
  value       = aws_db_instance.sensor_history.db_name
  description = "Nombre de la base PostgreSQL usada para el historico de sensores."
}

output "sensor_history_db_username" {
  value       = aws_db_instance.sensor_history.username
  description = "Usuario administrador de PostgreSQL para Lambda y API."
}

output "sensor_history_db_password" {
  value       = random_password.sensor_history.result
  description = "Password generado para PostgreSQL."
  sensitive   = true
}
