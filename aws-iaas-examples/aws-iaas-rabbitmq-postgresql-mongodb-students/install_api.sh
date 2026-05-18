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

