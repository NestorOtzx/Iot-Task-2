# Variables base del proyecto ALB
variable "vpc_id" {
  default = "vpc-04182cca7699596a2"
}

variable "ami_id" {
  default = "ami-02dfbd4ff395f2a1b" # Amazon Linux 2023
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  default = "callanor2026_02"
}

# Subredes en 3 zonas distintas para Alta Disponibilidad
variable "subnets" {
  default = [
    "subnet-065e8b30cff0a381e", # us-east-1a
    "subnet-0c74db342f01174f4", # us-east-1b
    "subnet-074b098cd02efd710"  # us-east-1c
  ]
}
