import os
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

import boto3
import pg8000.dbapi
from botocore.exceptions import ClientError
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field


# Configuracion inyectada por Terraform/ECS.
# Mantenerla en variables de entorno permite reutilizar la misma imagen entre ambientes.
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
SENSOR_TABLE_NAME = os.environ["SENSOR_TABLE_NAME"]
RDS_HOST = os.environ["RDS_HOST"]
RDS_PORT = int(os.environ.get("RDS_PORT", "5432"))
RDS_DB_NAME = os.environ["RDS_DB_NAME"]
RDS_USERNAME = os.environ["RDS_USERNAME"]
RDS_PASSWORD = os.environ["RDS_PASSWORD"]

# DynamoDB mantiene la vista caliente: sensores registrados, dato actual y ultimos 10 eventos.
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
sensor_table = dynamodb.Table(SENSOR_TABLE_NAME)

app = FastAPI(
    title="IoT Sensor API",
    description="API para registrar sensores y consultar datos actuales, recientes e historicos.",
    version="1.0.0",
)


class SensorCreate(BaseModel):
    """Contrato de entrada para registrar un sensor listo para publicar datos."""

    device_id: str = Field(..., min_length=1, description="ID que usara el sensor fisico en CLIENT_ID.")
    sensor_type: str = Field(..., min_length=1, description="Tipo del sensor, por ejemplo temperature o humidity.")
    description: str | None = Field(default=None, description="Descripcion opcional del sensor.")
    sensor_unit: str | None = Field(default=None, description="Unidad opcional, por ejemplo C, %, lux o custom.")


def _now_iso() -> str:
    """Devuelve un timestamp UTC consistente para metadatos creados por la API."""
    return datetime.now(timezone.utc).isoformat()


def _to_json_safe(value: Any) -> Any:
    """Convierte tipos de DynamoDB/PostgreSQL a valores serializables por FastAPI."""
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, list):
        return [_to_json_safe(item) for item in value]
    if isinstance(value, dict):
        return {key: _to_json_safe(item) for key, item in value.items()}
    return value


def _get_sensor_or_404(device_id: str) -> dict[str, Any]:
    """Busca un sensor en DynamoDB y responde 404 si no esta registrado."""
    response = sensor_table.get_item(Key={"device_id": device_id})
    sensor = response.get("Item")
    if not sensor:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor no encontrado")
    return sensor


def _connect_to_postgres():
    """Abre una conexion nueva a PostgreSQL para consultas historicas."""
    return pg8000.dbapi.connect(
        host=RDS_HOST,
        port=RDS_PORT,
        database=RDS_DB_NAME,
        user=RDS_USERNAME,
        password=RDS_PASSWORD,
        timeout=10,
    )


def _ensure_history_table(cursor) -> None:
    """Garantiza que la consulta historica funcione incluso antes del primer evento S3."""
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


@app.get("/health")
def health() -> dict[str, str]:
    """Endpoint liviano usado por el Load Balancer para health checks."""
    return {"status": "ok"}


@app.get("/sensors")
def list_sensors() -> dict[str, list[dict[str, Any]]]:
    """Lista metadatos de sensores sin incluir registros recientes ni actuales."""
    sensors: list[dict[str, Any]] = []
    scan_kwargs: dict[str, Any] = {
        "ProjectionExpression": "device_id, sensor_type, description, sensor_unit, #status, created_by, created_at, updated_at",
        "ExpressionAttributeNames": {"#status": "status"},
    }

    while True:
        response = sensor_table.scan(**scan_kwargs)
        sensors.extend(_to_json_safe(item) for item in response.get("Items", []))
        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break
        scan_kwargs["ExclusiveStartKey"] = last_key

    return {"sensors": sensors}


@app.post("/sensors", status_code=status.HTTP_201_CREATED)
def create_sensor(sensor: SensorCreate) -> dict[str, Any]:
    """Registra un sensor vacio; la ingesta IoT solo actualizara sensores existentes."""
    now = _now_iso()
    item: dict[str, Any] = {
        "device_id": sensor.device_id,
        "sensor_type": sensor.sensor_type,
        "description": sensor.description or "",
        "status": "registered",
        "created_by": "api",
        "created_at": now,
        "updated_at": now,
        "recent_events": [],
    }

    if sensor.sensor_unit:
        item["sensor_unit"] = sensor.sensor_unit

    try:
        sensor_table.put_item(Item=item, ConditionExpression="attribute_not_exists(device_id)")
    except ClientError as error:
        if error.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El sensor ya existe",
            ) from error
        raise

    return {"sensor": _to_json_safe(item)}


@app.get("/sensor/{device_id}/current")
def get_current_sensor_value(device_id: str) -> dict[str, Any]:
    """Devuelve el evento actual guardado en DynamoDB para un sensor."""
    sensor = _get_sensor_or_404(device_id)
    current_event = sensor.get("current_event")
    if not current_event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sensor sin datos actuales")

    return {
        "device_id": device_id,
        "sensor_type": sensor.get("sensor_type"),
        "current_event": _to_json_safe(current_event),
    }


@app.get("/sensor/{device_id}/recent")
def get_recent_sensor_values(device_id: str) -> dict[str, Any]:
    """Devuelve la ventana caliente de hasta 10 eventos recientes desde DynamoDB."""
    sensor = _get_sensor_or_404(device_id)
    return {
        "device_id": device_id,
        "sensor_type": sensor.get("sensor_type"),
        "recent_events": _to_json_safe(sensor.get("recent_events", [])),
    }


@app.get("/sensor/{device_id}/history")
def get_sensor_history(device_id: str) -> dict[str, Any]:
    """Devuelve el historico completo del sensor desde PostgreSQL RDS."""
    sensor = _get_sensor_or_404(device_id)
    connection = _connect_to_postgres()

    try:
        cursor = connection.cursor()
        _ensure_history_table(cursor)
        cursor.execute(
            """
            SELECT id, device_id, sensor_type, value, event_timestamp, source_bucket, source_key, ingested_at
            FROM sensor_history
            WHERE device_id = %s
            ORDER BY event_timestamp DESC
            """,
            (device_id,),
        )
        rows = cursor.fetchall()
        connection.commit()
    finally:
        connection.close()

    history = [
        {
            "id": row[0],
            "device_id": row[1],
            "sensor_type": row[2],
            "value": row[3],
            "timestamp": row[4],
            "source_bucket": row[5],
            "source_key": row[6],
            "ingested_at": row[7],
        }
        for row in rows
    ]

    return {
        "device_id": device_id,
        "sensor_type": sensor.get("sensor_type"),
        "history": _to_json_safe(history),
    }
