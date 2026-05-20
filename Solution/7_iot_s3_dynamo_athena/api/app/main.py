import os
import time
from decimal import Decimal

import boto3
import pg8000.dbapi
from botocore.exceptions import ClientError
from fastapi import FastAPI, HTTPException


# Configuracion general de AWS y nombres de recursos inyectados por Docker Compose o ECS.
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
SENSOR_TABLE_NAME = os.environ.get("SENSOR_TABLE_NAME", "SensorData-lab")
ATHENA_DATABASE = os.environ.get("ATHENA_DATABASE", "iot_edge_lab_analytics")
ATHENA_TABLE = os.environ.get("ATHENA_TABLE", "sensor_data")
ATHENA_RESULTS_BUCKET = os.environ.get("ATHENA_RESULTS_BUCKET", "")

# Configuracion de PostgreSQL. En local se puede pasar por variables de entorno y en ECS la inyecta Terraform.
PG_HOST = os.environ.get("PG_HOST", "")
PG_PORT = int(os.environ.get("PG_PORT", "5432"))
PG_DATABASE = os.environ.get("PG_DATABASE", "iot_metadata")
PG_USER = os.environ.get("PG_USER", "iot_admin")
PG_PASSWORD = os.environ.get("PG_PASSWORD", "")

# Clientes reutilizables de AWS. boto3 resuelve credenciales desde variables, perfil local o rol ECS.
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
athena = boto3.client("athena", region_name=AWS_REGION)

app = FastAPI(
    title="IoT Sensor API",
    description="API unificada para consultar DynamoDB, PostgreSQL y Athena.",
    version="1.0.0",
)


def _json_safe(value):
    """Convierte tipos de AWS/PostgreSQL a estructuras serializables por JSON."""
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)

    if hasattr(value, "isoformat"):
        return value.isoformat()

    if isinstance(value, list):
        return [_json_safe(item) for item in value]

    if isinstance(value, dict):
        return {key: _json_safe(item) for key, item in value.items()}

    return value


def _postgres_connection():
    """Abre conexion a RDS PostgreSQL usando pg8000, sin drivers nativos."""
    if not PG_HOST or not PG_PASSWORD:
        raise HTTPException(
            status_code=500,
            detail="PostgreSQL no esta configurado. Define PG_HOST y PG_PASSWORD.",
        )

    return pg8000.dbapi.connect(
        host=PG_HOST,
        port=PG_PORT,
        database=PG_DATABASE,
        user=PG_USER,
        password=PG_PASSWORD,
        timeout=10,
    )


def _athena_output_location():
    """Construye la ruta S3 donde Athena guardara los resultados de consulta."""
    if not ATHENA_RESULTS_BUCKET:
        raise HTTPException(
            status_code=500,
            detail="Athena no esta configurado. Define ATHENA_RESULTS_BUCKET.",
        )

    return f"s3://{ATHENA_RESULTS_BUCKET}/api-results/"


def _wait_for_athena_query(query_execution_id):
    """Espera hasta que Athena termine la consulta o reporte error."""
    while True:
        response = athena.get_query_execution(QueryExecutionId=query_execution_id)
        status = response["QueryExecution"]["Status"]["State"]

        if status == "SUCCEEDED":
            return

        if status in ["FAILED", "CANCELLED"]:
            reason = response["QueryExecution"]["Status"].get("StateChangeReason", "Sin detalle")
            raise HTTPException(status_code=502, detail=f"Consulta Athena {status}: {reason}")

        time.sleep(1)


def _athena_results(query_execution_id):
    """Transforma el resultado tabular de Athena en lista de diccionarios."""
    response = athena.get_query_results(QueryExecutionId=query_execution_id)
    rows = response["ResultSet"]["Rows"]

    if not rows:
        return []

    headers = [column.get("VarCharValue", "") for column in rows[0]["Data"]]
    results = []

    for row in rows[1:]:
        values = [column.get("VarCharValue") for column in row.get("Data", [])]
        results.append(dict(zip(headers, values)))

    return results


@app.get("/health")
def health():
    """Endpoint simple para validar que el contenedor esta vivo."""
    return {"status": "ok"}


@app.get("/sensor/{sensor_id}/current")
def sensor_current(sensor_id: str):
    """Obtiene el estado actual del sensor desde DynamoDB."""
    table = dynamodb.Table(SENSOR_TABLE_NAME)

    try:
        response = table.get_item(Key={"device_id": sensor_id})
    except ClientError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error

    item = response.get("Item")
    if not item:
        raise HTTPException(status_code=404, detail="Sensor no encontrado en DynamoDB")

    return {"source": "dynamodb", "sensor_id": sensor_id, "item": _json_safe(item)}


@app.get("/sensor/{sensor_id}/recent")
def sensor_recent(sensor_id: str):
    """Obtiene los ultimos 10 eventos del sensor desde PostgreSQL."""
    connection = _postgres_connection()

    try:
        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT
                device_id,
                sensor_type,
                value,
                event_timestamp,
                source_bucket,
                source_key,
                created_at
            FROM sensor_events
            WHERE device_id = %s
            ORDER BY event_timestamp DESC, created_at DESC
            LIMIT 10
            """,
            (sensor_id,),
        )

        columns = [column[0] for column in cursor.description]
        rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
    except Exception as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    finally:
        connection.close()

    return {"source": "postgresql", "sensor_id": sensor_id, "events": _json_safe(rows)}


@app.get("/sensor/{sensor_id}/report")
def sensor_report(sensor_id: str):
    """Ejecuta una consulta analitica en Athena sobre el historico de S3."""
    escaped_sensor_id = sensor_id.replace("'", "''")
    query = f"""
    SELECT
        device_id,
        sensor_type,
        COUNT(*) AS total_events,
        AVG(value) AS avg_value,
        MIN(value) AS min_value,
        MAX(value) AS max_value,
        MIN("timestamp") AS first_event,
        MAX("timestamp") AS last_event
    FROM {ATHENA_TABLE}
    WHERE device_id = '{escaped_sensor_id}'
    GROUP BY device_id, sensor_type
    """

    try:
        response = athena.start_query_execution(
            QueryString=query,
            QueryExecutionContext={"Database": ATHENA_DATABASE},
            ResultConfiguration={"OutputLocation": _athena_output_location()},
        )
        query_execution_id = response["QueryExecutionId"]
        _wait_for_athena_query(query_execution_id)
        rows = _athena_results(query_execution_id)
    except ClientError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error

    return {
        "source": "athena",
        "sensor_id": sensor_id,
        "query_execution_id": query_execution_id,
        "rows": rows,
    }
