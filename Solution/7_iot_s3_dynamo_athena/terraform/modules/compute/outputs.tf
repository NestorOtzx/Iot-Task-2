output "alert_lambda_arn" {
  value       = aws_lambda_function.lambda_alerta.arn
  description = "ARN de la Lambda invocada por la regla de IoT Core para alertas."
}

output "alert_lambda_function_name" {
  value       = aws_lambda_function.lambda_alerta.function_name
  description = "Nombre de la Lambda invocada por la regla de IoT Core para alertas."
}

output "alert_queue_url" {
  value       = aws_sqs_queue.alert_queue.url
  description = "URL de la cola SQS que transporta alertas criticas."
}

output "emergency_log_group_name" {
  value       = aws_cloudwatch_log_group.emergency_alerts.name
  description = "Nombre del log group dedicado para alertas de urgencia."
}

output "s3_to_postgres_lambda_name" {
  value       = aws_lambda_function.s3_to_postgres.function_name
  description = "Nombre de la Lambda que inserta eventos de S3 en PostgreSQL."
}

output "api_ecr_repository_url" {
  value       = aws_ecr_repository.api.repository_url
  description = "URL del repositorio ECR donde se debe subir la imagen Docker de la API."
}

output "api_ecs_cluster_name" {
  value       = aws_ecs_cluster.api.name
  description = "Nombre del cluster ECS que aloja la API."
}

output "api_ecs_service_name" {
  value       = aws_ecs_service.api.name
  description = "Nombre del servicio ECS de la API."
}
