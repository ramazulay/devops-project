#!/usr/bin/env python3
"""
SQS to S3 Processor Microservice

This microservice continuously polls an SQS queue for messages and uploads them to S3.
It runs in a loop, checking for messages at configurable intervals.
"""

import os
import json
import time
import logging
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Environment variables
AWS_REGION = os.getenv('AWS_REGION', 'us-west-1')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')
S3_BUCKET_NAME = os.getenv('S3_BUCKET_NAME')
POLL_INTERVAL = int(os.getenv('POLL_INTERVAL_SECONDS', '30'))  # Poll every 30 seconds by default
MAX_MESSAGES = int(os.getenv('MAX_MESSAGES_PER_POLL', '10'))  # Max messages per poll
S3_PREFIX = os.getenv('S3_PREFIX', 'sqs-messages/')  # S3 folder path

# Validate required environment variables
if not SQS_QUEUE_URL:
    raise ValueError("SQS_QUEUE_URL environment variable is required")
if not S3_BUCKET_NAME:
    raise ValueError("S3_BUCKET_NAME environment variable is required")

# Initialize AWS clients
sqs_client = boto3.client('sqs', region_name=AWS_REGION)
s3_client = boto3.client('s3', region_name=AWS_REGION)

# Health check flag
last_successful_poll = time.time()
health_status = {'status': 'starting', 'last_poll': None, 'messages_processed': 0}


def poll_sqs_messages():
    """
    Poll SQS queue for messages.
    
    Returns:
        list: List of messages received from SQS
    """
    try:
        logger.info(f"Polling SQS queue: {SQS_QUEUE_URL}")
        
        response = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=MAX_MESSAGES,
            WaitTimeSeconds=20,  # Long polling
            MessageAttributeNames=['All'],
            AttributeNames=['All']
        )
        
        messages = response.get('Messages', [])
        logger.info(f"Received {len(messages)} message(s) from SQS")
        
        return messages
    
    except ClientError as e:
        logger.error(f"Error polling SQS: {e}")
        health_status['status'] = 'unhealthy'
        return []
    except Exception as e:
        logger.error(f"Unexpected error polling SQS: {e}")
        health_status['status'] = 'unhealthy'
        return []


def upload_message_to_s3(message):
    """
    Upload a single SQS message to S3.
    
    Args:
        message (dict): SQS message to upload
        
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        message_id = message['MessageId']
        receipt_handle = message['ReceiptHandle']
        message_body = message['Body']
        
        # Create a unique filename using timestamp and message ID
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H')
        filename = f"{S3_PREFIX}{timestamp}/{message_id}.json"
        
        # Prepare the data to upload
        data_to_upload = {
            'message_id': message_id,
            'body': message_body,
            'attributes': message.get('Attributes', {}),
            'message_attributes': message.get('MessageAttributes', {}),
            'received_at': datetime.utcnow().isoformat(),
            'receipt_handle': receipt_handle
        }
        
        # Try to parse body as JSON if possible
        try:
            parsed_body = json.loads(message_body)
            data_to_upload['parsed_body'] = parsed_body
        except json.JSONDecodeError:
            logger.debug(f"Message body is not JSON, storing as string")
        
        # Upload to S3
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=filename,
            Body=json.dumps(data_to_upload, indent=2),
            ContentType='application/json',
            Metadata={
                'message-id': message_id,
                'processed-at': datetime.utcnow().isoformat()
            }
        )
        
        logger.info(f"Successfully uploaded message {message_id} to s3://{S3_BUCKET_NAME}/{filename}")
        
        # Delete message from SQS after successful upload
        sqs_client.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=receipt_handle
        )
        
        logger.info(f"Deleted message {message_id} from SQS queue")
        
        return True
    
    except ClientError as e:
        logger.error(f"Error uploading message to S3: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error processing message: {e}")
        return False


def process_messages():
    """
    Main processing loop: poll SQS and upload messages to S3.
    """
    global last_successful_poll, health_status
    
    messages_processed_this_cycle = 0
    
    # Poll for messages
    messages = poll_sqs_messages()
    
    if messages:
        logger.info(f"Processing {len(messages)} message(s)")
        
        for message in messages:
            success = upload_message_to_s3(message)
            if success:
                messages_processed_this_cycle += 1
                health_status['messages_processed'] += 1
        
        logger.info(f"Successfully processed {messages_processed_this_cycle}/{len(messages)} message(s)")
    else:
        logger.info("No messages to process")
    
    # Update health status
    last_successful_poll = time.time()
    health_status['status'] = 'healthy'
    health_status['last_poll'] = datetime.utcnow().isoformat()


def main():
    """
    Main entry point for the SQS processor.
    """
    logger.info("=" * 80)
    logger.info("SQS to S3 Processor Microservice Starting")
    logger.info("=" * 80)
    logger.info(f"AWS Region: {AWS_REGION}")
    logger.info(f"SQS Queue URL: {SQS_QUEUE_URL}")
    logger.info(f"S3 Bucket: {S3_BUCKET_NAME}")
    logger.info(f"S3 Prefix: {S3_PREFIX}")
    logger.info(f"Poll Interval: {POLL_INTERVAL} seconds")
    logger.info(f"Max Messages Per Poll: {MAX_MESSAGES}")
    logger.info("=" * 80)
    
    # Verify S3 bucket exists
    try:
        s3_client.head_bucket(Bucket=S3_BUCKET_NAME)
        logger.info(f"✓ S3 bucket '{S3_BUCKET_NAME}' is accessible")
    except ClientError as e:
        logger.error(f"✗ Cannot access S3 bucket '{S3_BUCKET_NAME}': {e}")
        logger.error("Exiting...")
        return
    
    # Verify SQS queue exists
    try:
        sqs_client.get_queue_attributes(
            QueueUrl=SQS_QUEUE_URL,
            AttributeNames=['ApproximateNumberOfMessages']
        )
        logger.info(f"✓ SQS queue is accessible")
    except ClientError as e:
        logger.error(f"✗ Cannot access SQS queue: {e}")
        logger.error("Exiting...")
        return
    
    logger.info("Starting message processing loop...")
    
    # Main processing loop
    while True:
        try:
            process_messages()
            
            # Wait before next poll
            logger.info(f"Waiting {POLL_INTERVAL} seconds before next poll...")
            time.sleep(POLL_INTERVAL)
            
        except KeyboardInterrupt:
            logger.info("Received shutdown signal, stopping gracefully...")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}")
            health_status['status'] = 'unhealthy'
            time.sleep(POLL_INTERVAL)  # Wait before retrying
    
    logger.info("SQS Processor stopped")


if __name__ == '__main__':
    main()
