variable "project_name" { type = string }
variable "environment" { type = string }
variable "lab_role_arn" { type = string }
variable "region" { type = string }
variable "sensor_bucket_name" { type = string }
variable "athena_results_bucket_name" { type = string }
variable "athena_database_name" { type = string }
variable "athena_table_name" { type = string }
variable "sensor_table_name" { type = string }
variable "postgres_endpoint" { type = string }
variable "postgres_port" { type = number }
variable "postgres_db_name" { type = string }
variable "postgres_username" { type = string }

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "api_desired_count" {
  description = "Cantidad de tareas ECS deseadas para la API. Se deja en 0 hasta subir la imagen Docker a ECR."
  type        = number
  default     = 0
}
