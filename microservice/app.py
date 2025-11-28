"""
Email Processing Microservice
Receives REST requests, validates token and data, then publishes to SQS
"""
import os
import json
import logging
from datetime import datetime
from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# AWS clients
ssm_client = boto3.client('ssm', region_name=os.getenv('AWS_REGION', 'us-west-1'))
sqs_client = boto3.client('sqs', region_name=os.getenv('AWS_REGION', 'us-west-1'))

# Configuration
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')
TOKEN_SSM_PARAMETER = os.getenv('TOKEN_SSM_PARAMETER', '/email-service/api-token')
REQUIRED_FIELDS = ['email_subject', 'email_sender', 'email_timestream', 'email_content']


def get_token_from_ssm():
    """
    Retrieve the validation token from AWS SSM Parameter Store
    """
    try:
        response = ssm_client.get_parameter(
            Name=TOKEN_SSM_PARAMETER,
            WithDecryption=True
        )
        return response['Parameter']['Value']
    except ClientError as e:
        logger.error(f"Error retrieving token from SSM: {e}")
        raise


def validate_token(provided_token):
    """
    Validate the provided token against the stored token in SSM
    """
    try:
        stored_token = get_token_from_ssm()
        return provided_token == stored_token
    except Exception as e:
        logger.error(f"Token validation failed: {e}")
        return False


def validate_data_fields(data):
    """
    Validate that all required fields are present in the data
    Returns tuple: (is_valid, error_message)
    """
    if not isinstance(data, dict):
        return False, "Data must be a dictionary"
    
    missing_fields = [field for field in REQUIRED_FIELDS if field not in data]
    
    if missing_fields:
        return False, f"Missing required fields: {', '.join(missing_fields)}"
    
    # Check that all required fields have values (not None or empty string)
    empty_fields = [field for field in REQUIRED_FIELDS if not data.get(field)]
    if empty_fields:
        return False, f"Empty fields not allowed: {', '.join(empty_fields)}"
    
    return True, None


def validate_timestamp(timestamp_str):
    """
    Validate that the timestamp is a valid Unix timestamp
    """
    try:
        timestamp = int(timestamp_str)
        # Check if timestamp is reasonable (between year 2000 and 2100)
        if timestamp < 946684800 or timestamp > 4102444800:
            return False, "Timestamp out of reasonable range"
        return True, None
    except (ValueError, TypeError):
        return False, "Invalid timestamp format"


def publish_to_sqs(data):
    """
    Publish validated data to SQS queue
    """
    try:
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(data),
            MessageAttributes={
                'ContentType': {
                    'StringValue': 'application/json',
                    'DataType': 'String'
                },
                'ProcessedAt': {
                    'StringValue': datetime.utcnow().isoformat(),
                    'DataType': 'String'
                }
            }
        )
        logger.info(f"Message published to SQS. MessageId: {response['MessageId']}")
        return True, response['MessageId']
    except ClientError as e:
        logger.error(f"Error publishing to SQS: {e}")
        return False, str(e)


@app.route('/health', methods=['GET'])
def health_check():
    """
    Health check endpoint for ELB
    """
    return jsonify({
        'status': 'healthy',
        'service': 'email-processor',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/process', methods=['POST'])
def process_email():
    """
    Main endpoint to process email data
    Validates token and data, then publishes to SQS
    """
    try:
        # Parse request JSON
        request_data = request.get_json()
        
        if not request_data:
            return jsonify({
                'status': 'error',
                'message': 'Invalid JSON payload'
            }), 400
        
        # Extract token and data
        token = request_data.get('token')
        data = request_data.get('data')
        
        # Validate token presence
        if not token:
            return jsonify({
                'status': 'error',
                'message': 'Token is required'
            }), 401
        
        # Validate data presence
        if not data:
            return jsonify({
                'status': 'error',
                'message': 'Data is required'
            }), 400
        
        # Validate token correctness
        if not validate_token(token):
            logger.warning(f"Invalid token attempt from {request.remote_addr}")
            return jsonify({
                'status': 'error',
                'message': 'Invalid token'
            }), 401
        
        # Validate data fields
        is_valid, error_message = validate_data_fields(data)
        if not is_valid:
            return jsonify({
                'status': 'error',
                'message': error_message
            }), 400
        
        # Validate timestamp
        is_valid_timestamp, timestamp_error = validate_timestamp(data['email_timestream'])
        if not is_valid_timestamp:
            return jsonify({
                'status': 'error',
                'message': f"Invalid timestamp: {timestamp_error}"
            }), 400
        
        # Publish to SQS
        success, message_id_or_error = publish_to_sqs(data)
        
        if success:
            logger.info(f"Email data processed successfully. MessageId: {message_id_or_error}")
            return jsonify({
                'status': 'success',
                'message': 'Email data processed and queued',
                'message_id': message_id_or_error
            }), 200
        else:
            logger.error(f"Failed to publish to SQS: {message_id_or_error}")
            return jsonify({
                'status': 'error',
                'message': 'Failed to queue email data'
            }), 500
            
    except Exception as e:
        logger.error(f"Unexpected error processing request: {e}")
        return jsonify({
            'status': 'error',
            'message': 'Internal server error'
        }), 500


@app.route('/', methods=['GET'])
def root():
    """
    Root endpoint with service information
    """
    return jsonify({
        'service': 'email-processor',
        'version': '1.0.0',
        'endpoints': {
            'health': '/health',
            'process': '/process (POST)'
        }
    }), 200


if __name__ == '__main__':
    # Validate required environment variables
    if not SQS_QUEUE_URL:
        logger.error("SQS_QUEUE_URL environment variable is required")
        exit(1)
    
    port = int(os.getenv('PORT', 8080))
    logger.info(f"Starting email processor service on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
