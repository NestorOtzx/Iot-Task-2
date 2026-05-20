output "sensor_table_name" {
  value       = aws_dynamodb_table.sensor_data.name
  description = "Nombre de la tabla DynamoDB para los datos del sensor"
}

output "postgres_endpoint" {
  value       = aws_db_instance.postgres_metadata.address
  description = "Endpoint DNS de RDS PostgreSQL."
}

output "postgres_port" {
  value       = aws_db_instance.postgres_metadata.port
  description = "Puerto de RDS PostgreSQL."
}

output "postgres_db_name" {
  value       = aws_db_instance.postgres_metadata.db_name
  description = "Nombre de la base PostgreSQL."
}

output "postgres_username" {
  value       = aws_db_instance.postgres_metadata.username
  description = "Usuario administrador de PostgreSQL."
}

output "postgres_password" {
  value       = random_password.rds_password.result
  description = "Password generado para PostgreSQL."
  sensitive   = true
}
