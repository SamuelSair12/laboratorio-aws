import json
import os
import uuid
from datetime import datetime
import boto3

# Inicialización de clientes AWS fuera del handler para reutilizar conexiones
dynamodb = boto3.resource('dynamodb')
events = boto3.client('events')

TABLE_NAME = os.environ.get('ORDERS_TABLE_NAME')
EVENT_BUS_NAME = os.environ.get('EVENT_BUS_NAME')

def handler(event, context):
    try:
        # Extraer el cuerpo de la petición
        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else event.get('body', {})
        
        order_id = body.get('orderId', str(uuid.uuid4()))
        customer_id = body.get('customerId')
        total = body.get('total')
        
        # Validar campos requeridos
        if not customer_id or total is None:
            return {
                'statusCode': 400,
                'body': json.dumps({'message': 'customerId y total son requeridos'})
            }

        created_at = datetime.utcnow().isoformat() + "Z"
        
        # 1. Guardar la orden en DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        item = {
            'orderId': order_id,
            'customerId': customer_id,
            'total': total,
            'status': 'CREATED',
            'createdAt': created_at
        }
        table.put_item(Item=item)
        
        # 2. Publicar evento OrderCreated en EventBridge
        detail_payload = {
            'orderId': order_id,
            'customerId': customer_id,
            'total': total,
            'status': 'CREATED',
            'createdAt': created_at
        }
        
        response = events.put_events(
            Entries=[
                {
                    'Source': 'com.cloudopsarena.orders',
                    'DetailType': 'OrderCreated',
                    'Detail': json.dumps(detail_payload),
                    'EventBusName': EVENT_BUS_NAME
                }
            ]
        )
        
        return {
            'statusCode': 201,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(item)
        }
        
    except Exception as e:
        print(f"Error procesando la orden: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Internal Server Error', 'error': str(e)})
        }
