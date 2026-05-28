variable "project_name" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "lab_role_arn" { type = string }
variable "sensor_table_name" { type = string }

variable "rds_host" { type = string }
variable "rds_port" { type = number }
variable "rds_db_name" { type = string }
variable "rds_username" { type = string }

variable "rds_password" {
  type      = string
  sensitive = true
}

variable "api_image_tag" {
  description = "Tag usado para construir y desplegar la imagen Docker de FastAPI."
  type        = string
  default     = "latest"
}

variable "api_desired_count" {
  description = "Cantidad de tareas ECS de la API."
  type        = number
  default     = 1
}
