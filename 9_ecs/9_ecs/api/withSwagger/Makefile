.PHONY: deploy clean destroy update-image

REGION = us-east-1
REPO_NAME = api-fastapi-repo

# 0. Actualizar solo la imagen de Docker en ECR y forzar a ECS a reiniciar las tareas
update-image:
	@echo "Obteniendo Account ID..."
	$(eval ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text))
	$(eval REPO_URI := $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(REPO_NAME))
	@echo "Haciendo login en ECR..."
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com
	@echo "Construyendo y subiendo la imagen..."
	docker build -t $(REPO_NAME) ./api
	docker tag $(REPO_NAME):latest $(REPO_URI):latest
	docker push $(REPO_URI):latest
	@echo "Forzando a ECS a descargar la nueva imagen..."
	aws ecs update-service --cluster swagger-fastapi-cluster --service swagger-fastapi-service --force-new-deployment
	@echo "Imagen actualizada y ECS reiniciando tareas."

# 1. Ejecutar el script completo de construcción y despliegue
deploy:
	chmod +x build_and_deploy.sh
	./build_and_deploy.sh

# 2. Limpiar archivos locales generados y el entorno virtual
clean:
	rm -rf venv/
	rm -f terraform/openapi_with_extensions.json
	find . -type d -name "__pycache__" -exec rm -rf {} +

# 3. Destruir infraestructura de Terraform y limpiar sus archivos locales
destroy:
	cd terraform && terraform destroy -auto-approve || echo "No se pudo destruir (o no había nada que destruir)"
	rm -rf terraform/.terraform/
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/terraform.tfstate*
	rm -f terraform/project.tfplan

destroy-all: destroy clean
