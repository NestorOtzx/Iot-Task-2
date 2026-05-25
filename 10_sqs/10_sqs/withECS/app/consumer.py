import boto3
import os
import time
import json
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    queue_url = os.environ.get('QUEUE_URL')
    region = os.environ.get('AWS_REGION', 'us-east-1')
    
    if not queue_url:
        logger.error("QUEUE_URL environment variable is not set.")
        return

    sqs = boto3.client('sqs', region_name=region)
    logger.info(f"Starting SQS consumer for queue: {queue_url}")

    while True:
        try:
            # Long polling for messages
            response = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20
            )

            messages = response.get('Messages', [])
            if not messages:
                logger.debug("No messages received. Waiting...")
                continue

            for message in messages:
                receipt_handle = message['ReceiptHandle']
                body = message['Body']
                message_id = message['MessageId']

                logger.info(f"Processing message ID '{message_id}': {body}")

                # Delete message after successful processing
                sqs.delete_message(
                    QueueUrl=queue_url,
                    ReceiptHandle=receipt_handle
                )
                logger.info(f"Deleted message ID '{message_id}' from queue.")

        except Exception as e:
            logger.error(f"Error receiving/processing messages: {e}")
            time.sleep(5)

if __name__ == '__main__':
    main()
