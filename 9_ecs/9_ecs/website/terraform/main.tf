terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  environment  = var.environment
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

module "ecs" {
  source       = "./modules/ecs"
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id          = module.networking.vpc_id
  subnet_ids      = module.networking.public_subnet_ids
  ecs_sg_id       = module.networking.ecs_sg_id
  target_group_arn = module.networking.target_group_arn
  ecr_repository_url = module.ecr.repository_url
  
  lab_role_arn    = data.aws_iam_role.lab_role.arn
}
