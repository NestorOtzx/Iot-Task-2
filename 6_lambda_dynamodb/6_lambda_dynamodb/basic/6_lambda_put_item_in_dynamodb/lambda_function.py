import boto3
import json
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Inserta un elemento en una tabla de DynamoDB.

    Args:
        event (dict): El evento de Lambda, que debe contener un diccionario
                      con los atributos a insertar en la tabla DynamoDB.
        context (object): El objeto de contexto de Lambda.

    Returns:
        dict: Un diccionario con el resultado de la operación.
    """

    table_name = 'devices'
    table = dynamodb.Table(table_name)

    try:
        # Boto3/DynamoDB no soporta tipo 'float' directo. Lo convertimos a 'Decimal' usando json.loads
        item = json.loads(json.dumps(event), parse_float=Decimal)

        if not isinstance(item, dict):
            raise ValueError("El evento debe ser un diccionario.")

        response = table.put_item(Item=item)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Elemento insertado correctamente en la tabla {table_name}',
                'response': response
            })
        }

    except ValueError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'message': f"Error de validación: {str(e)}"
            })
        }
    except Exception as e:
        print(f"Error inesperado: {e}")  # Log para depuración
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f"Error interno del servidor: {str(e)}"
            })
        }

if __name__ == "__main__":
    event = {
        "id": "12345",
        "Amount": 199.99,
        "Item": "Wireless Headphones"
    }
    result = lambda_handler(event, None)
    print(result)
