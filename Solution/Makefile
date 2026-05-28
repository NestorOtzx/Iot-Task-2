.PHONY: terraform-init lambda-package terraform-apply-ecr terraform-apply-all docker-check aws-up aws-down api-push api-redeploy local-up local-down logs clean

AWS_REGION ?= us-east-1
PROJECT_NAME ?= iot-edge
ENVIRONMENT ?= lab
API_IMAGE_TAG ?= latest
API_REPOSITORY_NAME ?= $(PROJECT_NAME)-$(ENVIRONMENT)-api
API_ECS_CLUSTER ?= $(PROJECT_NAME)-$(ENVIRONMENT)-api
API_ECS_SERVICE ?= $(PROJECT_NAME)-$(ENVIRONMENT)-fastapi
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text)
API_ECR_REGISTRY ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
API_IMAGE_URI ?= $(API_ECR_REGISTRY)/$(API_REPOSITORY_NAME):$(API_IMAGE_TAG)

# --- Comandos AWS (Terraform) ---

terraform-init:
	mkdir -p edge_gateway/certs
	cd terraform && terraform init

lambda-package:
	rm -rf terraform/modules/compute/.build/s3_to_rds
	mkdir -p terraform/modules/compute/.build/s3_to_rds
	cp terraform/src/s3_to_rds/lambda_function.py terraform/modules/compute/.build/s3_to_rds/
	pip3 install -r terraform/src/s3_to_rds/requirements.txt -t terraform/modules/compute/.build/s3_to_rds

terraform-apply-ecr: terraform-init lambda-package
	cd terraform && terraform apply -target=module.api.aws_ecr_repository.api -auto-approve

terraform-apply-all: terraform-init lambda-package
	cd terraform && terraform apply -auto-approve

aws-up: terraform-apply-ecr api-push terraform-apply-all
	@echo "Desplegando infraestructura en AWS IoT Core, DynamoDB, S3 y ECS..."
	@echo "Infraestructura desplegada. Certificados y mosquitto.conf han sido generados."

docker-check:
	@command -v docker >/dev/null 2>&1 || (echo "Docker CLI no esta instalado en esta imagen. Reconstruye la imagen raiz." && exit 1)
	@docker info >/dev/null 2>&1 || (echo "Docker CLI existe, pero no puede conectarse al daemon. Ejecuta el contenedor montando /var/run/docker.sock:/var/run/docker.sock." && exit 1)

api-push: docker-check
	@echo "Subiendo imagen FastAPI a ECR: $(API_IMAGE_URI)"
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(API_ECR_REGISTRY)
	docker build -t $(API_REPOSITORY_NAME):$(API_IMAGE_TAG) ./api
	docker tag $(API_REPOSITORY_NAME):$(API_IMAGE_TAG) $(API_IMAGE_URI)
	docker push $(API_IMAGE_URI)

api-redeploy: api-push
	@echo "Forzando nuevo despliegue ECS para usar la imagen publicada..."
	aws ecs update-service --region $(AWS_REGION) --cluster $(API_ECS_CLUSTER) --service $(API_ECS_SERVICE) --force-new-deployment

aws-down:
	@echo "Destruyendo infraestructura en AWS..."
	cd terraform && terraform destroy -auto-approve
	@echo "Infraestructura de AWS destruida."

# --- Comandos Locales (Docker Compose) ---

local-up:
	@echo "Levantando Edge Gateway (Mosquitto) y Sensores locales..."
	docker compose up -d --build
	@echo "Contenedores iniciados. Usa 'make logs' para ver el flujo de datos."

local-down:
	@echo "Deteniendo contenedores locales..."
	docker compose down
	@echo "Contenedores detenidos."

logs:
	docker compose logs -f

clean: local-down aws-down
	@echo "Limpiando certificados locales..."
	rm -rf edge_gateway/certs/*
	rm -f edge_gateway/mosquitto.conf
	@echo "Entorno limpio."
