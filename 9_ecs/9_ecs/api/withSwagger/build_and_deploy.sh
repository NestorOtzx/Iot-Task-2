#!/bin/bash

# Configura estas variables o asegúrate de que AWS CLI esté configurado
REGION="us-east-1"
REPO_NAME="api-fastapi-repo"

echo "=== 1. Preparando el entorno virtual para generar Swagger ==="
# Usamos un entorno virtual para no ensuciar el sistema
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r api/requirements.txt -q

echo "=== 2. Generando el Swagger (openapi_with_extensions.json) ==="
cd api
python generate_swagger.py
if [ $? -ne 0 ]; then
    echo "Error generando Swagger"
    exit 1
fi
mv openapi_with_extensions.json ../terraform/
cd ..

echo "=== 3. Obtener Account ID de AWS ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Error obteniendo el Account ID. ¿Está configurado AWS CLI?"
    exit 1
fi

# Opcional: Crear repositorio ECR si no existe
echo "Verificando si el repositorio ECR existe..."
aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creando el repositorio ECR: $REPO_NAME..."
    aws ecr create-repository \
        --repository-name $REPO_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --image-tag-mutability MUTABLE
fi

echo "=== 4. Construir y subir imagen Docker ==="
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
REPO_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

docker build -t $REPO_NAME ./api
docker tag $REPO_NAME:latest $REPO_URI:latest
docker push $REPO_URI:latest

echo "=== 5. Desplegando Infraestructura con Terraform ==="
cd terraform
terraform init
terraform plan -out=project.tfplan
terraform apply "project.tfplan"
cd ..

echo "=== Proceso Completado ==="
