import json
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3
import pg8000.dbapi


# Cliente reutilizable de S3. Lambda puede reutilizar este objeto si conserva el contenedor caliente.
s3_client = boto3.client("s3")

# Configuracion de PostgreSQL inyectada por Terraform desde los outputs del modulo database.
PG_HOST = os.environ["PG_HOST"]
PG_PORT = int(os.environ.get("PG_PORT", "5432"))
PG_DATABASE = os.environ["PG_DATABASE"]
PG_USER = os.environ["PG_USER"]
PG_PASSWORD = os.environ["PG_PASSWORD"]


def _parse_timestamp(value):
    """Convierte el timestamp ISO del sensor a datetime timezone-aware."""
    if not value:
        return datetime.now(timezone.utc)

    try:
        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed
    except ValueError:
        print(f"Timestamp invalido recibido; se usara hora actual: {value}")
        return datetime.now(timezone.utc)


def _connect():
    """Abre una conexion directa a PostgreSQL usando pg8000, una libreria pura de Python."""
    return pg8000.dbapi.connect(
        host=PG_HOST,
        port=PG_PORT,
        database=PG_DATABASE,
        user=PG_USER,
        password=PG_PASSWORD,
    )


def _ensure_schema(connection):
    """Crea la tabla e indices si aun no existen."""
    cursor = connection.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS sensor_events (
            id BIGSERIAL PRIMARY KEY,
            device_id TEXT NOT NULL,
            sensor_type TEXT NOT NULL,
            value DOUBLE PRECISION NOT NULL,
            event_timestamp TIMESTAMPTZ NOT NULL,
            source_bucket TEXT NOT NULL,
            source_key TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT sensor_events_source_unique UNIQUE (source_bucket, source_key)
        )
        """
    )

    cursor.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_sensor_events_device_time
        ON sensor_events (device_id, event_timestamp DESC)
        """
    )


def _insert_event(connection, payload, bucket, key):
    """Inserta el evento historico recibido desde S3 en PostgreSQL."""
    event_timestamp = _parse_timestamp(payload.get("timestamp"))
    cursor = connection.cursor()

    cursor.execute(
        """
        INSERT INTO sensor_events (
            device_id,
            sensor_type,
            value,
            event_timestamp,
            source_bucket,
            source_key
        )
        VALUES (
            %s,
            %s,
            %s,
            %s,
            %s,
            %s
        )
        ON CONFLICT (source_bucket, source_key) DO NOTHING
        """,
        (
            payload["device_id"],
            payload["sensor_type"],
            float(payload["value"]),
            event_timestamp,
            bucket,
            key,
        ),
    )


def _keep_last_ten_events(connection, device_id):
    """Elimina eventos antiguos y conserva solo los ultimos 10 registros por sensor."""
    cursor = connection.cursor()
    cursor.execute(
        """
        DELETE FROM sensor_events
        WHERE id IN (
            SELECT id
            FROM (
                SELECT
                    id,
                    ROW_NUMBER() OVER (
                        PARTITION BY device_id
                        ORDER BY event_timestamp DESC, created_at DESC, id DESC
                    ) AS row_number
                FROM sensor_events
                WHERE device_id = :device_id
            ) ranked_events
            WHERE ranked_events.row_number > 10
        )
        """,
        (device_id,),
    )


def _read_json_from_s3(bucket, key):
    """Lee y decodifica el archivo JSON que disparo el evento ObjectCreated."""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    body = response["Body"].read().decode("utf-8")
    return json.loads(body)


def _validate_payload(payload):
    """Valida los campos minimos que esperamos de los sensores."""
    required_fields = ["device_id", "sensor_type", "value", "timestamp"]
    missing_fields = [field for field in required_fields if field not in payload]

    if missing_fields:
        raise ValueError(f"Payload sin campos requeridos: {missing_fields}")


def lambda_handler(event, context):
    """Procesa objetos nuevos de S3, los persiste en PostgreSQL y aplica mantenimiento aciclico."""
    processed = 0
    connection = _connect()

    try:
        _ensure_schema(connection)

        # S3 puede agrupar varios objetos en una misma invocacion.
        for record in event.get("Records", []):
            bucket = record["s3"]["bucket"]["name"]
            key = unquote_plus(record["s3"]["object"]["key"])

            payload = _read_json_from_s3(bucket, key)
            _validate_payload(payload)
            _insert_event(connection, payload, bucket, key)
            _keep_last_ten_events(connection, payload["device_id"])
            connection.commit()

            print(f"Evento insertado y ciclo mantenido para {payload['device_id']}: s3://{bucket}/{key}")
            processed += 1

    finally:
        connection.close()

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Eventos procesados hacia PostgreSQL",
            "processed": processed
        })
    }
