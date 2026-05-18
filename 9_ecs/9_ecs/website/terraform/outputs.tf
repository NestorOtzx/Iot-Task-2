output "website_url" {
  description = "URL del Application Load Balancer para acceder al sitio web"
  value       = "http://${module.networking.alb_dns_name}"
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR"
  value       = module.ecr.repository_url
}
