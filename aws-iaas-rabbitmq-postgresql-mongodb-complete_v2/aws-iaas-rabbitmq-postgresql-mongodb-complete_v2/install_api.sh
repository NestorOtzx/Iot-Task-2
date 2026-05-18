#!/bin/bash
# Amazon Linux 2023 - Instalar Docker
sudo dnf update -y
sudo dnf install -y docker git

# Instalar Docker Compose (recomendado)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Habilitar y arrancar Docker
sudo systemctl enable docker
sudo systemctl start docker

# Añadir al usuario ec2-user al grupo docker
sudo usermod -aG docker ec2-user

# --- Despliegue de la API FastAPI ---

# Crear directorio para la API
mkdir -p /home/ec2-user/api
cd /home/ec2-user/api

# Crear main.py
cat <<EOF > main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "ok", "value": "Fixed Value from FastAPI"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
EOF

# Crear requirements.txt
cat <<EOF > requirements.txt
fastapi
uvicorn
EOF

# Crear Dockerfile
cat <<EOF > Dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Construir y ejecutar el contenedor
sudo docker build -t simple-api .
sudo docker run -d --restart=always --name fast-api -p 80:8000 simple-api
