output "ecr_repository_url" {
  description = "URL del repositorio ECR para hacer push de la imagen"
  value       = data.aws_ecr_repository.api_repo.repository_url
}

output "alb_dns_name" {
  description = "DNS del Load Balancer (tráfico directo a ECS)"
  value       = aws_lb.api_alb.dns_name
}

output "api_gateway_url" {
  description = "URL base del API Gateway (para consultar la API)"
  value       = aws_api_gateway_stage.api_stage.invoke_url
}
