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
