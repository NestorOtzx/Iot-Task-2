variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "iot-edge"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "lab"
}

variable "api_desired_count" {
  description = "Cantidad de tareas ECS de la API."
  type        = number
  default     = 1
}
