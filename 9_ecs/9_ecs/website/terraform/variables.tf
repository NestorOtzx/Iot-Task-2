variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "ecs-website"
}

variable "environment" {
  description = "Entorno (dev, prod)"
  type        = string
  default     = "dev"
}
