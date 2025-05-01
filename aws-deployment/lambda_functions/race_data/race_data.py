# race_data.py - Lambda function to handle race data requests
import json
import boto3
import os
import logging
from decimal import Decimal
from boto3.dynamodb.conditions import Key

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

# Get table name from environment variable
LAP_TABLE = os.environ.get('LAP_TABLE')
DRIVER_TABLE = os.environ.get('DRIVER_TABLE')

# Create a helper class for DynamoDB's Decimal serialization
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Lambda function handler for race data requests
    
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
    
    try:
        # Get session metadata
        session_info = get_session_info(session_uid)
        
        # Get lap data
        lap_data = get_lap_data(session_uid)
        
        # Get race standings
        race_standings = get_race_standings(session_uid)
        
        # Combine all data
        race_data = {
            'session_uid': session_uid,
            'session_info': session_info,
            'lap_data': lap_data,
            'race_standings': race_standings
        }
        
        # Return successful response
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(race_data, cls=DecimalEncoder)
        }
        
    except Exception as e:
        logger.error(f"Error retrieving race data: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': f"Internal server error: {str(e)}"})
        }

def get_session_info(session_uid):
    """
    Get session metadata from the drivers table
    
    Parameters:
        session_uid (str): Unique session identifier
        
    Returns:
        dict: Session information
    """
    # Access the drivers table to get session info
    table = dynamodb.Table(DRIVER_TABLE)
    
    # Query for any driver in the session to get session metadata
    response = table.query(
        IndexName='SessionIndex',
        KeyConditionExpression=Key('session_uid').eq(session_uid),
        Limit=1
    )
    
    items = response.get('Items', [])
    if not items:
        return {}
    
    # Extract session info from first item
    first_item = items[0]
    return {
        'track_id': first_item.get('track_id'),
        'session_type': first_item.get('session_type'),
        'formula': first_item.get('formula'),
        'game_version': first_item.get('game_version'),
        'date': first_item.get('date')
    }

def get_lap_data(session_uid):
    """
    Get lap data for all drivers in the session
    
    Parameters:
        session_uid (str): Unique session identifier
        
    Returns:
        list: Lap data for all drivers
    """
    # Access the lap data table
    table = dynamodb.Table(LAP_TABLE)
    
    # Query for all lap data in the session
    response = table.query(
        IndexName='SessionIndex',
        KeyConditionExpression=Key('session_uid').eq(session_uid)
    )
    
    items = response.get('Items', [])
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = table.query(
            IndexName='SessionIndex',
            KeyConditionExpression=Key('session_uid').eq(session_uid),
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        items.extend(response.get('Items', []))
    
    return items

def get_race_standings(session_uid):
    """
    Calculate race standings based on lap data
    
    Parameters:
        session_uid (str): Unique session identifier
        
    Returns:
        list: Current race standings
    """
    # Get all lap data
    lap_data = get_lap_data(session_uid)
    
    # Get all drivers in the session
    driver_table = dynamodb.Table(DRIVER_TABLE)
    response = driver_table.query(
        IndexName='SessionIndex',
        KeyConditionExpression=Key('session_uid').eq(session_uid)
    )
    
    drivers = response.get('Items', [])
    
    # Handle pagination
    while 'LastEvaluatedKey' in response:
        response = driver_table.query(
            IndexName='SessionIndex',
            KeyConditionExpression=Key('session_uid').eq(session_uid),
            ExclusiveStartKey=response['LastEvaluatedKey']
        )
        drivers.extend(response.get('Items', []))
    
    # Create standings based on current position
    standings = []
    for driver in drivers:
        driver_id = driver.get('driver_id')
        
        # Get the latest lap for this driver
        driver_laps = [lap for lap in lap_data if lap.get('driver_id') == driver_id]
        driver_laps.sort(key=lambda x: x.get('lap_number', 0), reverse=True)
        
        current_position = None
        if driver_laps:
            current_position = driver_laps[0].get('race_position')
        
        standings.append({
            'driver_id': driver_id,
            'name': driver.get('name'),
            'team': driver.get('team'),
            'current_position': current_position,
            'best_lap_time': min([lap.get('lap_time', float('inf')) for lap in driver_laps if lap.get('lap_time')], default=None),
            'last_lap_time': driver_laps[0].get('lap_time') if driver_laps else None,
            'total_laps': len(driver_laps)
        })
    
    # Sort by current position
    standings.sort(key=lambda x: x.get('current_position', float('inf')))
    
    return standings

def get_cors_headers():
    """Return headers for CORS support"""
    return {
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
        'Access-Control-Allow-Origin': '*'
    }