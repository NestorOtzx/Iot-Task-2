import json
import os
import sys
from datetime import datetime, timezone
from typing import Any
from urllib.parse import unquote_plus

import boto3

# Las dependencias puras de Python se guardan en vendor para que Terraform pueda comprimir
# la Lambda sin ejecutar pip ni Docker durante terraform apply.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "vendor"))

import pg8000.dbapi


# Clientes reutilizados entre invocaciones para reducir latencia en Lambda.
# boto3 viene incluido en el runtime de AWS Lambda.
s3_client = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

# Terraform inyecta estos valores para que el codigo no dependa de nombres fijos.
SENSOR_TABLE_NAME = os.environ["SENSOR_TABLE_NAME"]
RDS_HOST = os.environ["RDS_HOST"]
RDS_PORT = int(os.environ.get("RDS_PORT", "5432"))
RDS_DB_NAME = os.environ["RDS_DB_NAME"]
RDS_USERNAME = os.environ["RDS_USERNAME"]
RDS_PASSWORD = os.environ["RDS_PASSWORD"]

sensor_table = dynamodb.Table(SENSOR_TABLE_NAME)


def _connect_to_postgres():
    """Abre una conexion nueva a PostgreSQL para esta invocacion."""
    return pg8000.dbapi.connect(
        host=RDS_HOST,
        port=RDS_PORT,
        database=RDS_DB_NAME,
        user=RDS_USERNAME,
        password=RDS_PASSWORD,
        timeout=10,
    )


def _ensure_history_table(cursor):
    """Crea la tabla historica si es la primera vez que la Lambda se ejecuta."""
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS sensor_history (
            id BIGSERIAL PRIMARY KEY,
            device_id TEXT NOT NULL,
            sensor_type TEXT NOT NULL,
            value DOUBLE PRECISION NOT NULL,
            event_timestamp TIMESTAMPTZ NOT NULL,
            source_bucket TEXT NOT NULL,
            source_key TEXT NOT NULL,
            ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (source_bucket, source_key)
        )
        """
    )
    cursor.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_sensor_history_device_timestamp
        ON sensor_history (device_id, event_timestamp DESC)
        """
    )


def _load_json_object(bucket: str, key: str) -> dict[str, Any]:
    """Descarga desde S3 el JSON generado por la regla de IoT Core."""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    body = response["Body"].read().decode("utf-8")
    return json.loads(body)


def _normalize_timestamp(value: Any) -> str:
    """Usa el timestamp recibido o genera uno UTC si el payload no lo trae."""
    if value:
        return str(value)
    return datetime.now(timezone.utc).isoformat()


def _validate_payload(payload: dict[str, Any]) -> None:
    """Valida los campos minimos antes de escribir en PostgreSQL."""
    missing_fields = [field for field in ["device_id", "sensor_type", "value"] if field not in payload]
    if missing_fields:
        raise ValueError(f"Payload de sensor sin campos requeridos: {missing_fields}")


def _sensor_exists(device_id: str) -> bool:
    """Confirma que el sensor fue creado por Terraform o por POST /sensors antes de registrar historia."""
    response = sensor_table.get_item(Key={"device_id": device_id}, ProjectionExpression="device_id")
    return "Item" in response


def _insert_history_event(cursor, payload: dict[str, Any], bucket: str, key: str) -> None:
    """Inserta el evento historico sin duplicarlo si S3 reintenta la notificacion."""
    cursor.execute(
        """
        INSERT INTO sensor_history (
            device_id,
            sensor_type,
            value,
            event_timestamp,
            source_bucket,
            source_key
        )
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (source_bucket, source_key) DO NOTHING
        """,
        (
            payload["device_id"],
            payload["sensor_type"],
            float(payload["value"]),
            _normalize_timestamp(payload.get("timestamp")),
            bucket,
            key,
        ),
    )


def _process_record(record: dict[str, Any]) -> dict[str, Any]:
    """Procesa un unico objeto S3 y devuelve un resumen para los logs."""
    bucket = record["s3"]["bucket"]["name"]
    key = unquote_plus(record["s3"]["object"]["key"])
    payload = _load_json_object(bucket, key)
    _validate_payload(payload)

    device_id = payload["device_id"]
    if not _sensor_exists(device_id):
        print(f"Sensor '{device_id}' no registrado; no se inserta historico para {bucket}/{key}.")
        return {"bucket": bucket, "key": key, "device_id": device_id, "inserted": False}

    connection = _connect_to_postgres()
    try:
        cursor = connection.cursor()
        _ensure_history_table(cursor)
        _insert_history_event(cursor, payload, bucket, key)
        connection.commit()
    finally:
        connection.close()

    return {"bucket": bucket, "key": key, "device_id": device_id, "inserted": True}


def lambda_handler(event, context):
    """Punto de entrada de Lambda para eventos ObjectCreated de S3."""
    results = [_process_record(record) for record in event.get("Records", [])]
    print(json.dumps({"processed_records": results}))

    return {
        "statusCode": 200,
        "body": json.dumps({"processed_records": results}),
    }
