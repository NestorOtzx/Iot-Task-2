# Definimos las variables para no hardcodear todo si es posible
variable "vpc_id" {
  default = "vpc-0db51e24b1be9bc68"
}

variable "subnet_id" {
  default = "subnet-0a279d9c60a8ef4e0"
}

variable "subnet_id_2" {
  default = "subnet-0030ee3b0b7300432"
}

variable "ami_id" {
  default = "ami-02dfbd4ff395f2a1b" # Amazon Linux 2023
}

variable "key_name" {
  default = "callanor2026_02_iot"
}

variable "instance_type" {
  default = "t3.micro"
}
