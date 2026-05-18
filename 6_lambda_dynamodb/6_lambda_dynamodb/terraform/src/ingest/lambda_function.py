import json
import os
import boto3
from decimal import Decimal

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Ingests an IoT event and saves it to DynamoDB.
    Expected event payload:
    {
        "device_id": "sensor-01",
        "timestamp": "2023-10-27T10:00:00Z",
        "temperature": 22.5,
        "humidity": 60,
        "event_number": 1
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
    if not device_id:
        return {
            'statusCode': 400,
            'body': json.dumps('Missing device_id in event payload.')
        }
    
    # We expect the timestamp from the simulator, if not provided we error out
    timestamp = event.get('timestamp')
    if not timestamp:
        return {
            'statusCode': 400,
            'body': json.dumps('Missing timestamp in event payload.')
        }
    
    # Create the item to put in DynamoDB
    # Convert float to Decimal as boto3 requires it for DynamoDB
    item = {
        'device_id': device_id,
        'timestamp': timestamp,
        'temperature': Decimal(str(event.get('temperature', 0.0))),
        'humidity': Decimal(str(event.get('humidity', 0.0))),
        'event_number': event.get('event_number', 1),
        'raw_payload': json.dumps(event)
    }
    
    try:
        response = table.put_item(Item=item)
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Successfully inserted event via Lambda API',
                'device_id': device_id,
                'timestamp': timestamp
            })
        }
    except Exception as e:
        print(f"Error inserting into DynamoDB: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error saving event: {str(e)}')
        }

if __name__ == "__main__":
    # Configurar variable de entorno simulada para la prueba local
    os.environ['TABLE_NAME'] = 'iot_events'
    
    # Evento de prueba
    test_event = {
        "device_id": "sensor-01",
        "timestamp": "2026-04-29T09:15:21Z",
        "temperature": 25.5,
        "humidity": 50,
        "event_number": 12345
    }
    
    print("Probando lambda de ingesta localmente...")
    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))
