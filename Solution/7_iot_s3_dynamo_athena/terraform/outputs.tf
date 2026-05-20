output "iot_endpoint" {
  description = "El endpoint de AWS IoT Core"
  value       = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

output "alert_queue_url" {
  description = "URL de la cola SQS que recibe alertas criticas"
  value       = module.compute.alert_queue_url
}

output "sensor_bucket_name" {
  description = "Bucket S3 historico consultado por Athena"
  value       = module.storage.sensor_bucket_name
}

output "athena_results_bucket_name" {
  description = "Bucket S3 donde Athena escribe resultados"
  value       = module.storage.athena_results_bucket_name
}

output "athena_database_name" {
  description = "Base de datos Glue/Athena para analitica"
  value       = module.storage.athena_database_name
}

output "athena_table_name" {
  description = "Tabla Athena sobre sensor_data"
  value       = module.storage.athena_table_name
}

output "sensor_table_name" {
  description = "Tabla DynamoDB de datos actuales"
  value       = module.database.sensor_table_name
}

output "emergency_log_group_name" {
  description = "Log group de CloudWatch donde se registran alertas de urgencia"
  value       = module.compute.emergency_log_group_name
}

output "postgres_endpoint" {
  description = "Endpoint de RDS PostgreSQL para metadatos y eventos recientes"
  value       = module.database.postgres_endpoint
}

output "postgres_password" {
  description = "Password generado para RDS PostgreSQL"
  value       = module.database.postgres_password
  sensitive   = true
}

output "s3_to_postgres_lambda_name" {
  description = "Lambda que procesa JSON nuevos de S3 hacia PostgreSQL"
  value       = module.compute.s3_to_postgres_lambda_name
}

output "api_ecr_repository_url" {
  description = "Repositorio ECR donde se debe subir la imagen de FastAPI"
  value       = module.compute.api_ecr_repository_url
}

output "api_ecs_cluster_name" {
  description = "Cluster ECS de la API"
  value       = module.compute.api_ecs_cluster_name
}

output "api_ecs_service_name" {
  description = "Servicio ECS de la API"
  value       = module.compute.api_ecs_service_name
}
