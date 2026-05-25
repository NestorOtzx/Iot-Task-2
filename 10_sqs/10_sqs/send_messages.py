import argparse
import boto3
import datetime
import json
import sys

def get_queue_url(queue_name, region='us-east-1'):
    """Obtiene la URL de una cola SQS por su nombre usando boto3."""
    sqs = boto3.client('sqs', region_name=region)
    try:
        response = sqs.get_queue_url(QueueName=queue_name)
        print(response)
        return response['QueueUrl']
    except Exception as e:
        print(f"Error obteniendo la URL de la cola '{queue_name}': {e}")
        print("Asegúrate de que la infraestructura esté desplegada.")
        return None

def send_message(queue_url, message_body, region='us-east-1'):
    """Envía un mensaje a la cola SQS especificada usando boto3."""
    if not queue_url:
        print("La URL de la cola está vacía. ¿Se desplegó correctamente la infraestructura?")
        return

    sqs = boto3.client('sqs', region_name=region)
    try:
        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=message_body
        )
        print(f"Mensaje enviado a {queue_url}")
        print(f"MessageId: {response['MessageId']}")
    except Exception as e:
        print(f"Error al enviar mensaje: {e}")

def main():
    parser = argparse.ArgumentParser(description='Enviar mensajes de prueba a las colas SQS.')
    parser.add_argument('--target', choices=['lambda', 'ecs', 'both'], default='both', 
                        help='El destino del mensaje (lambda, ecs o both)')
    parser.add_argument('--message', type=str, default='Mensaje de prueba desde script Python local',
                        help='El contenido del mensaje a enviar')
    parser.add_argument('--count', type=int, default=1,
                        help='Número de mensajes a enviar (por defecto 1)')
    
    args = parser.parse_args()
    
    print("Obteniendo URLs de las colas usando boto3...")
    queue_urls = {
        'lambda': get_queue_url('my-lambda-queue'),
        'ecs': get_queue_url('my-ecs-queue')
    }
    
    if args.target in ['lambda', 'both']:
        print(f"\n--- Enviando {args.count} mensaje(s) a cola de Lambda ---")
        for i in range(args.count):
            msg_data = {
                "target": "lambda",
                "message": args.message,
                "message_id": i + 1,
                "total": args.count,
                "timestamp": datetime.datetime.now().isoformat()
            }
            send_message(queue_urls['lambda'], json.dumps(msg_data))
        
    if args.target in ['ecs', 'both']:
        print(f"\n--- Enviando {args.count} mensaje(s) a cola de ECS ---")
        for i in range(args.count):
            msg_data = {
                "target": "ecs",
                "message": args.message,
                "message_id": i + 1,
                "total": args.count,
                "timestamp": datetime.datetime.now().isoformat()
            }
            send_message(queue_urls['ecs'], json.dumps(msg_data))

if __name__ == '__main__':
    main()
