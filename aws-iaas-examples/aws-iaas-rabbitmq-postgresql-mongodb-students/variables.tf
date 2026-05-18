# Definimos las variables para no hardcodear todo si es posible
variable "vpc_id" {
  default = "vpc-04182cca7699596a2"
}

variable "subnet_id" {
  default = "subnet-065e8b30cff0a381e"
}

variable "ami_id" {
  default = "ami-02dfbd4ff395f2a1b" # Amazon Linux 2023
}

variable "key_name" {
  default = "callanor2026_02"
}

variable "instance_type" {
  default = "t3.micro"
}
