import boto3
import json
import os

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

# Get the table name from environment variable
TABLE_NAME = os.environ.get('TABLE_NAME')
if not TABLE_NAME:
    raise ValueError("TABLE_NAME environment variable must be set")

table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    """
    Retrieves an item from a DynamoDB table based on a provided key.

    Args:
        event (dict): Event data containing the key to retrieve.  Expects a 'key' field.
        context (object): Lambda context object (not used).

    Returns:
        dict: A dictionary containing the retrieved item or an error message.
              Example success: {"statusCode": 200, "body": {"item": { ... }}}
              Example error:   {"statusCode": 400, "body": {"error": "Key not provided"}}
    """
    try:
        if 'id' not in event:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Id not provided'}),
                'headers': {
                    'Content-Type': 'application/json'
                }
            }

        key_value = event['id']

        response = table.get_item(
            Key={
                'id': key_value
            }
        )

        if 'Item' in response:
            item = response['Item']
            return {
                'statusCode': 200,
                'body': json.dumps({'item': item}, default=str), # Use default=str to handle datatypes like Decimal
                'headers': {
                    'Content-Type': 'application/json'
                }
            }
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Item not found'}),
                'headers': {
                    'Content-Type': 'application/json'
                }
            }

    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)}),
            'headers': {
                'Content-Type': 'application/json'
            }
        }

if __name__ == "__main__":
    event = {
        "id": "12345"
    }
    result = lambda_handler(event, None)
    print(result)
