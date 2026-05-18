#!/bin/bash

# Configura estas variables o asegúrate de que AWS CLI esté configurado
REGION="us-east-1"
REPO_NAME="api-fastapi-repo"
CREATE_REPO=false

# Procesar parámetros
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --create-repo) CREATE_REPO=true; shift ;;
        *) echo "Parámetro desconocido: $1"; echo "Uso: $0 [--create-repo]"; exit 1 ;;
    esac
done

# Obtener el ID de la cuenta de AWS
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ $? -ne 0 ]; then
    echo "Error obteniendo el Account ID. ¿Está configurado AWS CLI?"
    exit 1
fi

echo "Account ID: $ACCOUNT_ID"

if [ "$CREATE_REPO" = true ]; then
    echo "Creando el repositorio ECR: $REPO_NAME..."
    aws ecr create-repository \
        --repository-name $REPO_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --image-tag-mutability MUTABLE || echo "El repositorio posiblemente ya existe o hubo un error."
fi

# Autenticarse en ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# URL del repositorio
REPO_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME"

echo "Construyendo la imagen de Docker..."
docker build -t $REPO_NAME ./api

echo "Etiquetando la imagen..."
docker tag $REPO_NAME:latest $REPO_URI:latest

echo "Subiendo la imagen a ECR..."
docker push $REPO_URI:latest

echo "Done"
