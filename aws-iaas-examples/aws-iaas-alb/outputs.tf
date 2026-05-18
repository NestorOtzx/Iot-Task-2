# OUTPUT: URL del Balanceador
output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "Copiar y pegar esta URL en tu navegador web"
}
