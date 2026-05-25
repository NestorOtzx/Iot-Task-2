#!/bin/bash

REGION="us-east-1"
REPO_NAME="sqs-consumer-repo"

echo "=== 1. Validando dependencias ==="
if ! command -v terraform &> /dev/null
then
    echo "Terraform no está instalado. Por favor instálalo."
    exit 1
fi

echo "=== 2. Obtener Account ID de AWS ==="
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ $? -ne 0 ]; then
    echo "Error obteniendo el Account ID. ¿Está configurado AWS CLI?"
    exit 1
fi

echo "=== 3. Construir Imagen Docker para ECS ==="
aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creando el repositorio ECR: $REPO_NAME..."
    aws ecr create-repository \
        --repository-name $REPO_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --image-tag-mutability MUTABLE
fi

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
REPO_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

docker build -t $REPO_NAME ./withECS/app
docker tag $REPO_NAME:latest $REPO_URI:latest
docker push $REPO_URI:latest

echo "=== 4. Desplegando Infraestructura (Lambda y ECS) con Terraform ==="
cd terraform
terraform init
terraform plan -out=project.tfplan
terraform apply "project.tfplan"
cd ..

echo "=== 5. Empaquetando y Desplegando Código Lambda ==="
echo "Empaquetando lambda_function.py..."
cd withLambda/lambda
zip -r lambda_function.zip .

echo "Actualizando código de la función en AWS Lambda..."
aws lambda update-function-code \
    --function-name SqsProcessorLambda \
    --zip-file fileb://lambda_function.zip \
    --region $REGION

# Limpieza del zip temporal
rm lambda_function.zip
cd ../..

echo "=== Proceso Completado ==="
