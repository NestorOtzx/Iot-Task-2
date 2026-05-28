variable "project_name" { type = string }
variable "environment" { type = string }
variable "lab_role_arn" { type = string }
variable "sensor_table_name" { type = string }
variable "sensor_bucket_name" { type = string }

variable "rds_host" { type = string }
variable "rds_port" { type = number }
variable "rds_db_name" { type = string }
variable "rds_username" { type = string }

variable "rds_password" {
  type      = string
  sensitive = true
}
