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

output "dynamodb_writer_lambda_arn" {
  value       = aws_lambda_function.dynamodb_retention_writer.arn
  description = "ARN de la Lambda que escribe en DynamoDB y aplica retencion de 10 eventos por sensor."
}

output "dynamodb_writer_lambda_function_name" {
  value       = aws_lambda_function.dynamodb_retention_writer.function_name
  description = "Nombre de la Lambda que escribe en DynamoDB y aplica retencion de 10 eventos por sensor."
}
