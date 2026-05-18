import json
import os
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

# Helper class to convert a DynamoDB item to JSON.
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return str(obj)
        return super(DecimalEncoder, self).default(obj)

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Queries DynamoDB for events of a specific device.
    Expected event payload options:
    
    Option 1: Solo por device_id
    {
        "device_id": "sensor-01"
    }

    Option 2: Rango de tiempo
    {
        "device_id": "sensor-01",
        "timestamp_start": "2023-10-01T00:00:00Z",
        "timestamp_end": "2023-10-31T23:59:59Z"
    }
    
    Option 3: Desde una fecha en adelante
    {
        "device_id": "sensor-01",
        "timestamp_start": "2023-10-01T00:00:00Z"
    }
    """
    table_name = os.environ.get('TABLE_NAME')
    if not table_name:
        return {
            'statusCode': 500,
            'body': json.dumps('TABLE_NAME environment variable not set.')
        }

    table = dynamodb.Table(table_name)
    
    device_id = event.get('device_id')
    timestamp_start = event.get('timestamp_start')
    timestamp_end = event.get('timestamp_end')

    if not device_id:
        return {
            'statusCode': 400,
            'body': json.dumps('Missing device_id in event payload.')
        }
    
    try:
        # Construir la expresion de llave primaria (Partition Key)
        key_expression = Key('device_id').eq(device_id)
        
        # Anadir la condicion de Sort Key (timestamp) si fue proveida
        if timestamp_start and timestamp_end:
            key_expression = key_expression & Key('timestamp').between(timestamp_start, timestamp_end)
        elif timestamp_start:
            key_expression = key_expression & Key('timestamp').gte(timestamp_start)
        elif timestamp_end:
            key_expression = key_expression & Key('timestamp').lte(timestamp_end)

        # Querying the table
        response = table.query(
            KeyConditionExpression=key_expression,
            # ScanIndexForward=False to get newest items first
            ScanIndexForward=False 
        )
        items = response.get('Items', [])
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'device_id': device_id,
                'count': len(items),
                'events': items
            }, cls=DecimalEncoder)
        }
    except Exception as e:
        print(f"Error querying DynamoDB: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error querying events: {str(e)}')
        }

if __name__ == "__main__":
    # Configurar variable de entorno simulada para la prueba local
    os.environ['TABLE_NAME'] = 'iot_events'
    
    print("--- Probando Lambda de Consulta Localmente ---\n")

    # Ejemplo 1: Consultar solo por device_id (trae todo)
    print("Ejemplo 1: Consultar todo el historial de 'sensor-01'")
    event_1 = {
        "device_id": "sensor-01"
    }
    result_1 = lambda_handler(event_1, None)
    # Solo imprimimos un resumen para no llenar la consola si hay muchos
    body_1 = json.loads(result_1['body'])
    print(f"Status: {result_1['statusCode']}, Registros encontrados: {body_1.get('count', 0)}\n")

    # Ejemplo 2: Consultar desde una fecha (Greater Than or Equal)
    print("Ejemplo 2: Consultar desde el 1 de Enero de 2024 en adelante")
    event_2 = {
        "device_id": "sensor-01",
        "timestamp_start": "2026-04-29T18:50:00Z"  # "2024-01-01T00:00:00Z"
    }
    result_2 = lambda_handler(event_2, None)
    body_2 = json.loads(result_2['body'])
    print(f"Status: {result_2['statusCode']}, Registros encontrados: {body_2.get('count', 0)}\n")

    # Ejemplo 3: Consultar en un rango de fechas (Between)
    print("Ejemplo 3: Rango especifico (Enero 2023 a Diciembre 2023)")
    event_3 = {
        "device_id": "sensor-01",
        "timestamp_start": "2026-04-29T09:12:21Z",
        "timestamp_end": "2026-04-29T09:15:21Z"
    }
    result_3 = lambda_handler(event_3, None)
    body_3 = json.loads(result_3['body'])
    print(f"Status: {result_3['statusCode']}, Registros encontrados: {body_3.get('count', 0)}\n")
