terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Módulo de Almacenamiento (S3)
module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
  environment  = var.environment
}

# Módulo de Base de Datos (DynamoDB)
module "database" {
  source       = "./modules/database"
  project_name = var.project_name
  environment  = var.environment
}

# Modulo de Computo (Lambdas, SQS y CloudWatch Logs)
module "compute" {
  source            = "./modules/compute"
  project_name      = var.project_name
  environment       = var.environment
  lab_role_arn      = data.aws_iam_role.lab_role.arn
  sensor_table_name = module.database.sensor_table_name
}

# Módulo de IoT Core
module "iot" {
  source       = "./modules/iot"
  project_name = var.project_name
  environment  = var.environment

  # Variables inyectadas desde data sources globales
  lab_role_arn = data.aws_iam_role.lab_role.arn
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name

  # iot_endpoint: Es la URL única (Endpoint ATS) asignada por AWS a tu cuenta y región para IoT Core.
  # Es indispensable inyectarla a Mosquitto (en su archivo mosquitto.conf) para que el Bridge sepa 
  # exactamente a qué dirección de servidor de Amazon debe conectarse y enviar los mensajes MQTT.
  iot_endpoint = data.aws_iot_endpoint.iot_endpoint.endpoint_address
  root_ca_pem  = data.http.root_ca.response_body

  # Variables inyectadas desde outputs de otros módulos
  sensor_bucket_name = module.storage.sensor_bucket_name
  # Lambda que recibe las alertas filtradas por IoT Core antes de enviarlas a SQS.
  alert_lambda_arn           = module.compute.alert_lambda_arn
  alert_lambda_function_name = module.compute.alert_lambda_function_name

  # Lambda que escribe en DynamoDB y mantiene un maximo de 10 registros por sensor.
  dynamodb_writer_lambda_arn           = module.compute.dynamodb_writer_lambda_arn
  dynamodb_writer_lambda_function_name = module.compute.dynamodb_writer_lambda_function_name
}
