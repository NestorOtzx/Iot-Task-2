#!/bin/bash
# Actualizar el sistema
yum update -y

# Instalar el servidor web Apache
yum install -y httpd

# Iniciar el servicio y habilitarlo para que arranque con el sistema
systemctl start httpd
systemctl enable httpd

# Crear una página HTML básica
echo "<h1>Bienvenido a la instancia EC2 desplegada con OpenTofu</h1>" > /var/www/html/index.html
