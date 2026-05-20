output "sensor_bucket_name" {
  value       = aws_s3_bucket.sensor_data.bucket
  description = "Nombre del bucket de S3 para sensores"
}

output "athena_results_bucket_name" {
  value       = aws_s3_bucket.athena_results.bucket
  description = "Nombre del bucket de S3 para Athena"
}

output "athena_database_name" {
  value       = aws_glue_catalog_database.iot_analytics.name
  description = "Base de datos Glue/Athena para analitica IoT"
}

output "athena_table_name" {
  value       = aws_glue_catalog_table.sensor_data.name
  description = "Tabla externa Athena sobre el historico de sensores"
}
