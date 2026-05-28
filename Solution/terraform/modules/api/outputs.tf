output "api_ecr_repository_url" {
  value       = aws_ecr_repository.api.repository_url
  description = "Repositorio ECR donde se publica la imagen Docker de FastAPI."
}

output "api_image_uri" {
  value       = local.api_image
  description = "Imagen Docker exacta que la task definition de ECS intenta ejecutar."
}

output "api_url" {
  value       = "http://${aws_lb.api.dns_name}"
  description = "URL publica estable del Load Balancer para consumir FastAPI."
}

output "api_cluster_name" {
  value       = aws_ecs_cluster.api.name
  description = "Nombre del cluster ECS donde corre FastAPI."
}

output "api_service_name" {
  value       = aws_ecs_service.api.name
  description = "Nombre del servicio ECS que ejecuta FastAPI."
}

output "api_container_port" {
  value       = 8000
  description = "Puerto interno del contenedor FastAPI registrado en el target group."
}

output "api_log_group_name" {
  value       = aws_cloudwatch_log_group.api.name
  description = "Log group de CloudWatch donde ECS envia los logs del contenedor FastAPI."
}

output "api_target_group_arn" {
  value       = aws_lb_target_group.api.arn
  description = "ARN del target group usado por el ALB para revisar targets healthy."
}
