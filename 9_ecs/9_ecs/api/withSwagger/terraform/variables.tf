variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "ecr_repo_name" {
  description = "Nombre del repositorio ECR para la imagen de FastAPI"
  type        = string
  default     = "api-fastapi-repo"
}

variable "container_port" {
  description = "Puerto expuesto por el contenedor"
  type        = number
  default     = 8000
}

variable "app_count" {
  description = "Número de contenedores a ejecutar"
  type        = number
  default     = 2
}
