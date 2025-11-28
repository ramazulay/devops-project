"""
Unit tests for the email processing microservice
"""
import os
import json
import pytest
from unittest.mock import patch, MagicMock
from app import app, validate_token, validate_data_fields, validate_timestamp


@pytest.fixture
def client():
    """Create a test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


@pytest.fixture
def mock_aws():
    """Mock AWS services"""
    with patch('app.ssm_client') as mock_ssm, \
         patch('app.sqs_client') as mock_sqs:
        
        # Mock SSM get_parameter
        mock_ssm.get_parameter.return_value = {
            'Parameter': {
                'Value': '$DJISA<$#45ex3RtYr'
            }
        }
        
        # Mock SQS send_message
        mock_sqs.send_message.return_value = {
            'MessageId': 'test-message-id-12345'
        }
        
        yield mock_ssm, mock_sqs


def test_health_check(client):
    """Test health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert data['service'] == 'email-processor'


def test_root_endpoint(client):
    """Test root endpoint"""
    response = client.get('/')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['service'] == 'email-processor'
    assert 'endpoints' in data


def test_valid_request(client, mock_aws):
    """Test valid email processing request"""
    payload = {
        "data": {
            "email_subject": "Happy new year!",
            "email_sender": "John doe",
            "email_timestream": "1693561101",
            "email_content": "Just want to say... Happy new year!!!"
        },
        "token": "$DJISA<$#45ex3RtYr"
    }
    
    response = client.post('/process',
                          data=json.dumps(payload),
                          content_type='application/json')
    
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'success'
    assert 'message_id' in data


def test_missing_token(client):
    """Test request with missing token"""
    payload = {
        "data": {
            "email_subject": "Test",
            "email_sender": "Test",
            "email_timestream": "1693561101",
            "email_content": "Test"
        }
    }
    
    response = client.post('/process',
                          data=json.dumps(payload),
                          content_type='application/json')
    
    assert response.status_code == 401
    data = json.loads(response.data)
    assert data['status'] == 'error'
    assert 'token' in data['message'].lower()


def test_invalid_token(client, mock_aws):
    """Test request with invalid token"""
    payload = {
        "data": {
            "email_subject": "Test",
            "email_sender": "Test",
            "email_timestream": "1693561101",
            "email_content": "Test"
        },
        "token": "invalid-token"
    }
    
    response = client.post('/process',
                          data=json.dumps(payload),
                          content_type='application/json')
    
    assert response.status_code == 401
    data = json.loads(response.data)
    assert data['status'] == 'error'
    assert 'Invalid token' in data['message']


def test_missing_data_field(client, mock_aws):
    """Test request with missing required field"""
    payload = {
        "data": {
            "email_subject": "Test",
            "email_sender": "Test",
            "email_timestream": "1693561101"
            # Missing email_content
        },
        "token": "$DJISA<$#45ex3RtYr"
    }
    
    response = client.post('/process',
                          data=json.dumps(payload),
                          content_type='application/json')
    
    assert response.status_code == 400
    data = json.loads(response.data)
    assert data['status'] == 'error'
    assert 'email_content' in data['message']


def test_empty_data_field(client, mock_aws):
    """Test request with empty field"""
    payload = {
        "data": {
            "email_subject": "",
            "email_sender": "Test",
            "email_timestream": "1693561101",
            "email_content": "Test"
        },
        "token": "$DJISA<$#45ex3RtYr"
    }
    
    response = client.post('/process',
                          data=json.dumps(payload),
                          content_type='application/json')
    
    assert response.status_code == 400
    data = json.loads(response.data)
    assert data['status'] == 'error'
    assert 'empty' in data['message'].lower()


def test_invalid_timestamp(client, mock_aws):
    """Test request with invalid timestamp"""
    payload = {
        "data": {
            "email_subject": "Test",
            "email_sender": "Test",
            "email_timestream": "not-a-timestamp",
            "email_content": "Test"
        },
        "token": "$DJISA<$#45ex3RtYr"
    }
    
    response = client.post('/process',
                          data=json.dumps(payload),
                          content_type='application/json')
    
    assert response.status_code == 400
    data = json.loads(response.data)
    assert data['status'] == 'error'
    assert 'timestamp' in data['message'].lower()


def test_timestamp_out_of_range(client, mock_aws):
    """Test request with timestamp out of reasonable range"""
    payload = {
        "data": {
            "email_subject": "Test",
            "email_sender": "Test",
            "email_timestream": "999999999999",  # Year ~33000
            "email_content": "Test"
        },
        "token": "$DJISA<$#45ex3RtYr"
    }
    
    response = client.post('/process',
                          data=json.dumps(payload),
                          content_type='application/json')
    
    assert response.status_code == 400
    data = json.loads(response.data)
    assert data['status'] == 'error'


def test_invalid_json(client):
    """Test request with invalid JSON"""
    response = client.post('/process',
                          data='not valid json',
                          content_type='application/json')
    
    assert response.status_code == 400


def test_validate_data_fields():
    """Test data field validation function"""
    # Valid data
    valid_data = {
        "email_subject": "Test",
        "email_sender": "Test",
        "email_timestream": "1693561101",
        "email_content": "Test"
    }
    is_valid, error = validate_data_fields(valid_data)
    assert is_valid is True
    assert error is None
    
    # Missing field
    invalid_data = {
        "email_subject": "Test",
        "email_sender": "Test",
        "email_timestream": "1693561101"
    }
    is_valid, error = validate_data_fields(invalid_data)
    assert is_valid is False
    assert "email_content" in error


def test_validate_timestamp():
    """Test timestamp validation function"""
    # Valid timestamp
    is_valid, error = validate_timestamp("1693561101")
    assert is_valid is True
    assert error is None
    
    # Invalid format
    is_valid, error = validate_timestamp("not-a-number")
    assert is_valid is False
    assert error is not None
    
    # Out of range
    is_valid, error = validate_timestamp("999999999999")
    assert is_valid is False
    assert error is not None
