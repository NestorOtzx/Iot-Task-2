.PHONY: all aws-up aws-down docker-build docker-push clean

PROJECT_NAME = ecs-website
ENV = dev
REGION = us-east-1
ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPO = $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(PROJECT_NAME)-repo-$(ENV)

all: aws-up

# Inicializa Terraform
terraform-init:
	cd terraform && terraform init

# Primero aplicamos solo el módulo de ECR
# Esto es necesario porque ECS necesita que la imagen exista en ECR antes de desplegarse
terraform-apply-ecr: terraform-init
	cd terraform && terraform apply -target=module.ecr -auto-approve

docker-build:
	cd app && docker build -t $(PROJECT_NAME) .
	docker tag $(PROJECT_NAME):latest $(ECR_REPO):latest

docker-push: docker-build
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ECR_REPO)
	docker push $(ECR_REPO):latest

# Aplica la infraestructura completa
terraform-apply-all: terraform-init
	cd terraform && terraform apply -auto-approve

# Ciclo completo de despliegue
aws-up: terraform-apply-ecr docker-push terraform-apply-all
	@echo "Sitio web desplegado exitosamente en ECS con Terraform."
	@echo "URL del sitio:"
	@cd terraform && terraform output website_url

# Ciclo completo de destrucción
aws-down:
	cd terraform && terraform destroy -auto-approve
	@echo "Recursos de AWS destruidos."

# Limpia los archivos generados por terraform
destroy-all: aws-down
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/terraform.tfstate
	rm -f terraform/terraform.tfstate.backup
	@echo "Archivos temporales y estado de Terraform eliminados."
