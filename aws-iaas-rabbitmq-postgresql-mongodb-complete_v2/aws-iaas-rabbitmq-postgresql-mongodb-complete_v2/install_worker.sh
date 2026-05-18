#!/bin/bash
# Amazon Linux 2023 - Instalar dependencias para un Worker (Python)
sudo dnf update -y
sudo dnf install -y python3 python3-pip git

# Se instalan algunas librerías genéricas si es necesario
pip3 install pika celery requests
