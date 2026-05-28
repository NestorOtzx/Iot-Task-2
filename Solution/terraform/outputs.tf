output "iot_endpoint" {
  description = "El endpoint de AWS IoT Core"
  value       = data.aws_iot_endpoint.iot_endpoint.endpoint_address
}

output "alert_queue_url" {
  description = "URL de la cola SQS que recibe alertas criticas"
  value       = module.compute.alert_queue_url
}

output "emergency_log_group_name" {
  description = "Log group de CloudWatch donde se registran alertas de urgencia"
  value       = module.compute.emergency_log_group_name
}

output "api_ecr_repository_url" {
  description = "Repositorio ECR usado para la imagen Docker de la API"
  value       = module.api.api_ecr_repository_url
}

output "api_image_uri" {
  description = "Imagen Docker exacta que ECS intenta ejecutar para la API"
  value       = module.api.api_image_uri
}

output "api_url" {
  description = "URL publica estable del Load Balancer para consumir la API FastAPI"
  value       = module.api.api_url
}

output "api_cluster_name" {
  description = "Nombre del cluster ECS donde corre la API FastAPI"
  value       = module.api.api_cluster_name
}

output "api_service_name" {
  description = "Nombre del servicio ECS que ejecuta la API FastAPI"
  value       = module.api.api_service_name
}

output "api_container_port" {
  description = "Puerto interno del contenedor FastAPI registrado en el target group"
  value       = module.api.api_container_port
}

output "api_log_group_name" {
  description = "Log group de CloudWatch donde ECS envia los logs del contenedor FastAPI"
  value       = module.api.api_log_group_name
}

output "api_target_group_arn" {
  description = "ARN del target group usado por el ALB de la API"
  value       = module.api.api_target_group_arn
}
