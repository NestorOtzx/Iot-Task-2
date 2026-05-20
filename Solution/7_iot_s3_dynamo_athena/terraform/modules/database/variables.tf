variable "project_name" { type = string }
variable "environment" { type = string }

variable "rds_db_name" {
  description = "Nombre de la base PostgreSQL para metadatos y eventos recientes."
  type        = string
  default     = "iot_metadata"
}

variable "rds_username" {
  description = "Usuario administrador de PostgreSQL."
  type        = string
  default     = "iot_admin"
}

variable "rds_instance_class" {
  description = "Clase de instancia RDS usada en el laboratorio."
  type        = string
  default     = "db.t3.micro"
}
