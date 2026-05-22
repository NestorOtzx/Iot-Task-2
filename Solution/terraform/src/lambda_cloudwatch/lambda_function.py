import json
import os
import time

import boto3


# Cliente reutilizable de CloudWatch Logs. Se usa boto3 de forma explicita para
# escribir las alertas de negocio en un log group dedicado, no solo en el log tecnico de Lambda.
logs_client = boto3.client("logs")

# Terraform crea estos recursos y los entrega como variables de entorno.
LOG_GROUP_NAME = os.environ["LOG_GROUP_NAME"]
LOG_STREAM_NAME = os.environ["LOG_STREAM_NAME"]


def _get_sequence_token():
    """Obtiene el token requerido por CloudWatch Logs para escribir en el stream."""
    response = logs_client.describe_log_streams(
        logGroupName=LOG_GROUP_NAME,
        logStreamNamePrefix=LOG_STREAM_NAME
    )

    for stream in response.get("logStreams", []):
        if stream.get("logStreamName") == LOG_STREAM_NAME:
            return stream.get("uploadSequenceToken")

    return None


def _write_cloudwatch_event(message):
    """Escribe un evento en el log stream dedicado para alertas de urgencia."""
    log_event = {
        "timestamp": int(time.time() * 1000),
        "message": message
    }

    # CloudWatch Logs usa un sequence token para mantener el orden dentro del stream.
    # Si no existe token, significa que el stream aun no ha recibido eventos.
    sequence_token = _get_sequence_token()
    put_args = {
        "logGroupName": LOG_GROUP_NAME,
        "logStreamName": LOG_STREAM_NAME,
        "logEvents": [log_event]
    }

    if sequence_token:
        put_args["sequenceToken"] = sequence_token

    logs_client.put_log_events(**put_args)


def lambda_handler(event, context):
    """Consume mensajes desde SQS y los registra en CloudWatch Logs."""

    processed = 0

    # Lambda entrega los mensajes de SQS en event["Records"]. Cada record contiene
    # el body que la Lambda de alerta envio previamente a la cola.
    for record in event.get("Records", []):
        alert = json.loads(record.get("body", "{}"))

        # Formato legible para que el log sea util desde la consola de CloudWatch.
        cloudwatch_message = json.dumps({
            "event": "IOT_URGENT_TEMPERATURE_ALERT",
            "alert_id": alert.get("alert_id"),
            "device_id": alert.get("device_id"),
            "value": alert.get("value"),
            "threshold": alert.get("threshold"),
            "severity": alert.get("severity"),
            "source_topic": alert.get("source_topic"),
            "sensor_timestamp": alert.get("sensor_timestamp"),
            "received_at": alert.get("received_at")
        })

        _write_cloudwatch_event(cloudwatch_message)
        print(f"Alerta registrada en CloudWatch Logs: {cloudwatch_message}")
        processed += 1

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Alertas procesadas",
            "processed": processed
        })
    }
