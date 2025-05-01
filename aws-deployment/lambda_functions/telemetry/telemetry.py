# telemetry.py - Lambda function to handle telemetry data requests
import json
import boto3
import os
import logging
from decimal import Decimal
from boto3.dynamodb.conditions import Key, Attr

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

# Get table name from environment variable
TELEMETRY_TABLE = os.environ.get('TELEMETRY_TABLE')
DRIVER_TABLE = os.environ.get('DRIVER_TABLE')
LAP_TABLE = os.environ.get('LAP_TABLE')

# Create a helper class for DynamoDB's Decimal serialization
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Lambda function handler for telemetry data requests
    
    Parameters:
        event (dict): API Gateway Lambda Proxy Input
        context (object): Lambda Context runtime methods and attributes
        
    Returns:
        dict: API Gateway Lambda Proxy Output
    """
    logger.info('Received event: %s', json.dumps(event))
    
    # Handle warm-up event
    if event.get('source') == 'warm-up':
        logger.info('Warm-up event received, no action needed')
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Warm-up completed'})
        }
    
    # Get query string parameters
    query_params = event.get('queryStringParameters', {}) or {}
    
    # Required parameter validation
    session_uid = query_params.get('session_uid')
    if not session_uid:
        return {
            'statusCode': 400,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': 'Missing required parameter: session_uid'})
        }
    
    # Optional parameters
    driver_id = query_params.get('driver_id')
    lap_number = query_params.get('lap_number')
    
    try:
        # Access the DynamoDB table
        table = dynamodb.Table(TELEMETRY_TABLE)
        
        # Build query based on provided parameters
        if driver_id and lap_number:
            # Query for a specific driver and lap
            response = table.query(
                IndexName='SessionIndex',
                KeyConditionExpression=Key('session_uid').eq(session_uid),
                FilterExpression=Attr('driver_id').eq(int(driver_id)) & Attr('lap_number').eq(int(lap_number))
            )
        elif driver_id:
            # Query for a specific driver across all laps
            response = table.query(
                IndexName='SessionIndex',
                KeyConditionExpression=Key('session_uid').eq(session_uid),
                FilterExpression=Attr('driver_id').eq(int(driver_id))
            )
        elif lap_number:
            # Query for all drivers in a specific lap
            response = table.query(
                IndexName='SessionIndex',
                KeyConditionExpression=Key('session_uid').eq(session_uid),
                FilterExpression=Attr('lap_number').eq(int(lap_number))
            )
        else:
            # Query for all telemetry data in the session
            response = table.query(
                IndexName='SessionIndex',
                KeyConditionExpression=Key('session_uid').eq(session_uid)
            )
        
        # Get results
        items = response.get('Items', [])
        
        # Handle pagination
        while 'LastEvaluatedKey' in response:
            response = table.query(
                IndexName='SessionIndex',
                KeyConditionExpression=Key('session_uid').eq(session_uid),
                ExclusiveStartKey=response['LastEvaluatedKey']
            )
            items.extend(response.get('Items', []))
        
        # Return successful response
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(
                {
                    'session_uid': session_uid,
                    'driver_id': driver_id,
                    'lap_number': lap_number,
                    'count': len(items),
                    'telemetry': items
                },
                cls=DecimalEncoder
            )
        }
        
    except Exception as e:
        logger.error(f"Error retrieving telemetry data: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': f"Internal server error: {str(e)}"})
        }

def get_cors_headers():
    """Return headers for CORS support"""
    return {
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
        'Access-Control-Allow-Origin': '*'
    }