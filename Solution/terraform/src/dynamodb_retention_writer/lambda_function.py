import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from boto3.dynamodb.types import TypeSerializer


# DynamoDB ya esta disponible en el runtime de Lambda por medio de boto3.
# Usamos el cliente de bajo nivel para escribir exactamente los tipos que necesita la tabla.
dynamodb_client = boto3.client("dynamodb")
serializer = TypeSerializer()

# Terraform inyecta el nombre real de la tabla para mantener el codigo portable entre ambientes.
SENSOR_TABLE_NAME = os.environ["SENSOR_TABLE_NAME"]
MAX_EVENTS_PER_SENSOR = int(os.environ.get("MAX_EVENTS_PER_SENSOR", "10"))


def _normalize_timestamp(value):
    """Garantiza que cada evento tenga un timestamp ISO ordenable lexicograficamente."""
    if value:
        return str(value)

    return datetime.now(timezone.utc).isoformat()


def _to_dynamodb_item(payload):
    """Convierte el payload JSON del sensor al formato tipado requerido por DynamoDB."""
    item = {
        "device_id": payload["device_id"],
        "timestamp": _normalize_timestamp(payload.get("timestamp")),
        "sensor_type": payload.get("sensor_type", "unknown"),
        "value": Decimal(str(payload.get("value"))),
    }

    return {key: serializer.serialize(value) for key, value in item.items() if value is not None}


def _validate_payload(payload):
    """Valida los campos minimos necesarios para escribir y mantener el historial."""
    missing_fields = [field for field in ["device_id", "value"] if field not in payload]

    if missing_fields:
        raise ValueError(f"Payload sin campos requeridos: {missing_fields}")


def _put_event(payload):
    """Inserta el nuevo evento en DynamoDB."""
    dynamodb_client.put_item(
        TableName=SENSOR_TABLE_NAME,
        Item=_to_dynamodb_item(payload),
    )


def _delete_events_after_first_ten(device_id):
    """Borra los eventos mas antiguos y conserva solo los ultimos 10 del sensor."""
    response = dynamodb_client.query(
        TableName=SENSOR_TABLE_NAME,
        KeyConditionExpression="device_id = :device_id",
        ExpressionAttributeValues={
            ":device_id": serializer.serialize(device_id),
        },
        ScanIndexForward=False,
    )

    old_events = response.get("Items", [])[MAX_EVENTS_PER_SENSOR:]

    for item in old_events:
        dynamodb_client.delete_item(
            TableName=SENSOR_TABLE_NAME,
            Key={
                "device_id": item["device_id"],
                "timestamp": item["timestamp"],
            },
        )

    return len(old_events)


def lambda_handler(event, context):
    """Recibe eventos desde IoT Core, los guarda en DynamoDB y aplica retencion por sensor."""
    _validate_payload(event)
    _put_event(event)
    deleted_count = _delete_events_after_first_ten(event["device_id"])

    print(
        json.dumps(
            {
                "message": "Evento guardado en DynamoDB con retencion aplicada",
                "device_id": event["device_id"],
                "deleted_old_events": deleted_count,
                "max_events_per_sensor": MAX_EVENTS_PER_SENSOR,
            }
        )
    )

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Evento guardado",
                "deleted_old_events": deleted_count,
            }
        ),
    }
