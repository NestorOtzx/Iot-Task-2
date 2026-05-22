# Thing que representa al Edge Gateway local dentro de AWS IoT Core.
resource "aws_iot_thing" "edge_gateway" {
  name = "edge-gateway-01-${var.environment}"
}

# Certificado X.509 usado por Mosquitto para autenticarse con IoT Core mediante mTLS.
resource "aws_iot_certificate" "cert" {
  active = true
}

# Politica de IoT para limitar que el certificado solo conecte y publique en los topicos del laboratorio.
resource "aws_iot_policy" "sensor_policy" {
  name = "EdgeGatewayPolicy-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["iot:Connect"]
        Effect   = "Allow"
        Resource = ["arn:aws:iot:${var.region}:${var.account_id}:client/${aws_iot_thing.edge_gateway.name}"]
      },
      {
        Action   = ["iot:Publish", "iot:Receive"]
        Effect   = "Allow"
        Resource = ["arn:aws:iot:${var.region}:${var.account_id}:topic/lab/sensors/*"]
      },
      {
        Action   = ["iot:Subscribe"]
        Effect   = "Allow"
        Resource = ["arn:aws:iot:${var.region}:${var.account_id}:topicfilter/lab/sensors/*"]
      }
    ]
  })
}

# Adjunta la politica al certificado para que el dispositivo tenga permisos efectivos.
resource "aws_iot_policy_attachment" "att" {
  policy = aws_iot_policy.sensor_policy.name
  target = aws_iot_certificate.cert.arn
}

# Relaciona el certificado con el Thing del Edge Gateway.
resource "aws_iot_thing_principal_attachment" "att" {
  principal = aws_iot_certificate.cert.arn
  thing     = aws_iot_thing.edge_gateway.name
}

# Escribe el certificado PEM localmente para que el contenedor Mosquitto lo use.
resource "local_file" "certificate_pem" {
  content  = aws_iot_certificate.cert.certificate_pem
  filename = "${path.root}/../edge_gateway/certs/certificate.pem.crt"
}

# Escribe la clave privada localmente. Este archivo es secreto y no debe compartirse.
resource "local_file" "private_key" {
  content  = aws_iot_certificate.cert.private_key
  filename = "${path.root}/../edge_gateway/certs/private.pem.key"
}

# Escribe la clave publica asociada al certificado.
resource "local_file" "public_key" {
  content  = aws_iot_certificate.cert.public_key
  filename = "${path.root}/../edge_gateway/certs/public.pem.key"
}

# Escribe el Amazon Root CA que permite validar el endpoint de AWS IoT Core.
resource "local_file" "root_ca" {
  content  = var.root_ca_pem
  filename = "${path.root}/../edge_gateway/certs/AmazonRootCA1.pem"
}

# Genera mosquitto.conf con el endpoint real de IoT Core y los paths de certificados del contenedor.
resource "local_file" "mosquitto_conf" {
  content  = <<-EOT
# Configuracion del servidor local Mosquitto
listener 1883 0.0.0.0
allow_anonymous true

# Configuracion del Bridge hacia AWS IoT Core
connection awsiot
address ${var.iot_endpoint}:8883

# Mapeo de topicos: local -> remoto
topic lab/sensors/data out 1 "" ""

bridge_protocol_version mqttv311
bridge_insecure false

cleansession true
clientid ${aws_iot_thing.edge_gateway.name}
start_type automatic
notifications false
keepalive_interval 60

# Certificados TLS para la conexion con AWS
bridge_cafile /mosquitto/certs/AmazonRootCA1.pem
bridge_certfile /mosquitto/certs/certificate.pem.crt
bridge_keyfile /mosquitto/certs/private.pem.key
EOT
  filename = "${path.root}/../edge_gateway/mosquitto.conf"
}

# Regla 1 de DynamoDB:
# Envia cada evento a una Lambda que escribe en DynamoDB y elimina registros antiguos para conservar 10 por sensor.
resource "aws_iot_topic_rule" "dynamodb_rule" {
  name        = "SensorDataToDynamoDB_${var.environment}"
  description = "Guarda los ultimos 10 eventos por sensor en DynamoDB"
  enabled     = true
  sql         = "SELECT * FROM 'lab/sensors/data'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = var.dynamodb_writer_lambda_arn
  }
}

# Permite que IoT Core invoque la Lambda de escritura y retencion de DynamoDB.
resource "aws_lambda_permission" "allow_iot_dynamodb_writer" {
  statement_id  = "AllowExecutionFromIoTDynamoDBRule${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = var.dynamodb_writer_lambda_function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.dynamodb_rule.arn
}

# Regla 2 de S3:
# Mantiene una copia historica de todos los eventos como JSON particionado por fecha.
resource "aws_iot_topic_rule" "s3_rule" {
  name        = "SensorDataToS3_${var.environment}"
  description = "Guarda los eventos de sensores en S3 particionados por fecha"
  enabled     = true
  sql         = "SELECT * FROM 'lab/sensors/data'"
  sql_version = "2016-03-23"

  s3 {
    bucket_name = var.sensor_bucket_name
    key         = "data/year=$${parse_time(\"yyyy\", timestamp())}/month=$${parse_time(\"MM\", timestamp())}/day=$${parse_time(\"dd\", timestamp())}/$${topic(3)}_$${newuuid()}.json"
    role_arn    = var.lab_role_arn
  }
}

# Regla 3 de Alertas por temperatura:
# Escucha eventos de temperatura mayores a 30 y dispara la Lambda de alertas hacia SQS/CloudWatch.
resource "aws_iot_topic_rule" "temperature_alert_rule" {
  name        = "TemperatureAlertToLambda_${var.environment}"
  description = "Dispara una Lambda cuando un sensor de temperatura supera el umbral critico"
  enabled     = true
  sql         = "SELECT *, topic() AS source_topic FROM 'lab/+/data' WHERE sensor_type = 'temperature' AND value > 30"
  sql_version = "2016-03-23"

  lambda {
    function_arn = var.alert_lambda_arn
  }
}

# Permite que IoT Core invoque la Lambda de alerta.
resource "aws_lambda_permission" "allow_iot_temperature_alert" {
  statement_id  = "AllowExecutionFromIoTAlertRule${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = var.alert_lambda_function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.temperature_alert_rule.arn
}
