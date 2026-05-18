import boto3
import json
import time
import random
from datetime import datetime, timezone

# Initialize Lambda client instead of DynamoDB
lambda_client = boto3.client('lambda', region_name='us-east-1')

# Configuración del simulador
FUNCTION_NAME = 'iot_ingest_lambda'
DEVICE_ID = 'sensor-01'
NUM_EVENTS = 10
DELAY_SECONDS = 2

def main():
    print(f"Iniciando simulación para el dispositivo '{DEVICE_ID}'...")
    print(f"Enviando {NUM_EVENTS} eventos a la Lambda '{FUNCTION_NAME}'\n")

    for i in range(1, NUM_EVENTS + 1):
        # Generar telemetría simulada
        temperature = round(random.uniform(20.0, 30.0), 2)
        humidity = round(random.uniform(40.0, 60.0), 2)
        timestamp = datetime.now(timezone.utc).isoformat()

        # Crear payload
        item = {
            'device_id': DEVICE_ID,
            'timestamp': timestamp,
            'temperature': temperature, # No need for Decimal here, JSON serialization handles floats
            'humidity': humidity,
            'event_number': i
        }

        try:
            print(f"[{i}/{NUM_EVENTS}] Invocando Lambda para el device {DEVICE_ID} - Evento: Temp: {temperature}C, Hum: {humidity}%, timestamp: {timestamp}")
            
            # Invoking the ingest Lambda
            response = lambda_client.invoke(
                FunctionName=FUNCTION_NAME,
                InvocationType='RequestResponse', # synchronous call
                Payload=json.dumps(item)
            )
            
            # Parse Lambda response
            response_payload = json.loads(response['Payload'].read().decode("utf-8"))
            
            if response_payload.get('statusCode') == 200:
                print("  -> Exito guardando a través de Lambda!")
            else:
                print(f"  -> Error reportado por Lambda: {response_payload}")
                
        except Exception as e:
            print(f"  -> Error invocando Lambda: {e}")

        if i < NUM_EVENTS:
            time.sleep(DELAY_SECONDS)

    print("\nSimulación completada.")

if __name__ == '__main__':
    main()
