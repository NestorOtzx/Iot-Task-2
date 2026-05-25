import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function that triggers on SQS events.
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    for record in event.get('Records', []):
        message_body = record.get('body')
        message_id = record.get('messageId')
        
        # In a real app, process the message here
        logger.info(f"Processing message ID '{message_id}' with body: {message_body}")

        # En lambda no hay necesidad de borrar el mensaje de la cola, 
        # ya que la cola está configurada para que la lambda
        # se ejecute cada vez que haya un mensaje en la cola y se borra automáticamente.
        
    return {
        'statusCode': 200,
        'body': json.dumps('Messages processed successfully!')
    }
