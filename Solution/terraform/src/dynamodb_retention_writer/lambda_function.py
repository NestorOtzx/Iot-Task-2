import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError


# DynamoDB ya esta disponible en el runtime de Lambda por medio de boto3.
# Usamos el resource de alto nivel porque trabaja naturalmente con documentos DynamoDB.
dynamodb = boto3.resource("dynamodb")

# Terraform inyecta el nombre real de la tabla para mantener el codigo portable entre ambientes.
SENSOR_TABLE_NAME = os.environ["SENSOR_TABLE_NAME"]
MAX_EVENTS_PER_SENSOR = int(os.environ.get("MAX_EVENTS_PER_SENSOR", "10"))

table = dynamodb.Table(SENSOR_TABLE_NAME)


class SensorNotRegisteredError(Exception):
    """El sensor publicó datos, pero todavía no existe como ítem en DynamoDB."""


def _normalize_timestamp(value):
    """Garantiza que cada evento tenga un timestamp ISO."""
    if value:
        return str(value)

    return datetime.now(timezone.utc).isoformat()


def _to_decimal(value):
    """Convierte números JSON a Decimal, que es el tipo numérico requerido por boto3 para DynamoDB."""
    return Decimal(str(value))


def _sensor_event(payload):
    """Normaliza el evento que se agregará al arreglo recent_events del sensor."""
    return {
        "sensor_type": payload.get("sensor_type", "unknown"),
        "value": _to_decimal(payload["value"]),
        "timestamp": _normalize_timestamp(payload.get("timestamp")),
    }


def _validate_payload(payload):
    """Valida los campos mínimos necesarios para actualizar un sensor existente."""
    missing_fields = [field for field in ["device_id", "value"] if field not in payload]

    if missing_fields:
        raise ValueError(f"Payload sin campos requeridos: {missing_fields}")


def _load_existing_sensor(device_id):
    """Obtiene el ítem del sensor y falla si todavía no fue creado por el flujo administrativo."""
    response = table.get_item(Key={"device_id": device_id})
    sensor = response.get("Item")

    if not sensor:
        raise SensorNotRegisteredError(
            f"El sensor '{device_id}' no existe en DynamoDB. Cree el sensor antes de publicar datos."
        )

    return sensor


def _recent_events_with_new_event(sensor, new_event):
    """Agrega el evento nuevo al inicio y conserva solo los últimos 10 registros."""
    previous_events = sensor.get("recent_events", [])
    return [new_event, *previous_events][:MAX_EVENTS_PER_SENSOR]


def _update_existing_sensor(device_id, new_event, recent_events):
    """Actualiza el ítem clave-valor del sensor sin crear sensores nuevos accidentalmente."""
    table.update_item(
        Key={"device_id": device_id},
        ConditionExpression="attribute_exists(device_id)",
        UpdateExpression="""
            SET
                sensor_type = :sensor_type,
                current_event = :current_event,
                last_value = :last_value,
                last_timestamp = :last_timestamp,
                recent_events = :recent_events,
                updated_at = :updated_at
        """,
        ExpressionAttributeValues={
            ":sensor_type": new_event["sensor_type"],
            ":current_event": new_event,
            ":last_value": new_event["value"],
            ":last_timestamp": new_event["timestamp"],
            ":recent_events": recent_events,
            ":updated_at": datetime.now(timezone.utc).isoformat(),
        },
    )


def lambda_handler(event, context):
    """Recibe eventos desde IoT Core y actualiza solo sensores previamente registrados."""
    _validate_payload(event)

    device_id = event["device_id"]
    try:
        new_event = _sensor_event(event)
        sensor = _load_existing_sensor(device_id)
        recent_events = _recent_events_with_new_event(sensor, new_event)
        _update_existing_sensor(device_id, new_event, recent_events)
    except SensorNotRegisteredError as error:
        print(str(error))
        return {
            "statusCode": 404,
            "body": json.dumps(
                {
                    "message": "Sensor no registrado",
                    "device_id": device_id,
                }
            ),
        }
    except ClientError as error:
        if error.response["Error"]["Code"] == "ConditionalCheckFailedException":
            message = f"El sensor '{device_id}' no existe en DynamoDB. Cree el sensor antes de publicar datos."
            print(message)
            return {
                "statusCode": 404,
                "body": json.dumps(
                    {
                        "message": "Sensor no registrado",
                        "device_id": device_id,
                    }
                ),
            }
        raise

    print(
        json.dumps(
            {
                "message": "Sensor actualizado en DynamoDB",
                "device_id": device_id,
                "recent_events_count": len(recent_events),
                "max_events_per_sensor": MAX_EVENTS_PER_SENSOR,
            }
        )
    )

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Sensor actualizado",
                "recent_events_count": len(recent_events),
            }
        ),
    }
