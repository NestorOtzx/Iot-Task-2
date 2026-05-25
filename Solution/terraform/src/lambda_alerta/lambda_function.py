import json
import os
import uuid
from datetime import datetime, timezone

import boto3


# Cliente reutilizable de SQS. Declararlo fuera del handler permite que AWS Lambda
# lo conserve entre invocaciones cuando reutiliza el mismo contenedor.
sqs_client = boto3.client("sqs")

# URL de la cola creada por Terraform. La Lambda no necesita conocer el nombre
# fisico de la cola; solo usa esta URL para enviar el mensaje.
ALERT_QUEUE_URL = os.environ["ALERT_QUEUE_URL"]


def _to_float(value):
    """Convierte el valor recibido desde IoT Core a float para validarlo."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def lambda_handler(event, context):
    """Recibe una alerta desde IoT Core y la publica en SQS."""

    # IoT Core ya filtro sensor_type='temperature' y value > 30, pero esta
    # validacion defensiva evita enviar mensajes mal formados si la regla cambia.
    sensor_type = event.get("sensor_type")
    value = _to_float(event.get("value"))

    if sensor_type != "temperature" or value is None or value <= 30:
        print(f"Evento ignorado porque no cumple el umbral de alerta: {event}")
        return {
            "statusCode": 202,
            "body": json.dumps({"message": "Evento ignorado"})
        }

    # Mensaje normalizado de emergencia. Este formato desacopla a CloudWatch
    # del payload MQTT original y facilita consumir la alerta desde otros servicios.
    alert_message = {
        "alert_id": str(uuid.uuid4()),
        "alert_type": "HIGH_TEMPERATURE",
        "severity": "URGENT",
        "device_id": event.get("device_id", "unknown"),
        "sensor_type": sensor_type,
        "value": value,
        "threshold": 30,
        "sensor_timestamp": event.get("timestamp"),
        "source_topic": event.get("source_topic", "unknown"),
        "received_at": datetime.now(timezone.utc).isoformat()
    }

    # Publica la alerta en SQS usando boto3. SQS se encarga de conservar el
    # mensaje hasta que la segunda Lambda lo procese correctamente.
    response = sqs_client.send_message(
        QueueUrl=ALERT_QUEUE_URL,
        MessageBody=json.dumps(alert_message),
        MessageAttributes={
            "severity": {
                "DataType": "String",
                "StringValue": alert_message["severity"]
            },
            "alert_type": {
                "DataType": "String",
                "StringValue": alert_message["alert_type"]
            }
        }
    )

    print(f"Alerta enviada a SQS: {alert_message}")
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Alerta enviada a SQS",
            "message_id": response.get("MessageId"),
            "alert_id": alert_message["alert_id"]
        })
    }
