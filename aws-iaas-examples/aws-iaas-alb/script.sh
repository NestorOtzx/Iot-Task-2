#!/bin/bash
# Actualizar sistema e instalar Apache
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Obtener los metadatos de la instancia usando IMDSv2
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
HOSTNAME=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-hostname`
AZ=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone`

# Crear el sitio web imprimiendo el Hostname y la Availability Zone
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
  <title>App Balanceada</title>
  <style>
    body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f4f6f9; }
    .box { background: white; padding: 30px; border-radius: 10px; display: inline-block; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
    h1 { color: #2c3e50; }
    .info { color: #e74c3c; font-weight: bold; font-size: 1.2em; }
  </style>
</head>
<body>
  <div class="box">
    <h1>¡Hola! Soy un servidor web en AWS</h1>
    <p>Estoy respondiendo a la peticion del Load Balancer.</p>
    <p>Hostname: <span class="info">$HOSTNAME</span></p>
    <p>Availability Zone: <span class="info">$AZ</span></p>
  </div>
</body>
</html>
EOF
