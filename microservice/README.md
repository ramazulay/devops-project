# Email Processing Microservice

A REST API microservice that processes email data requests, validates tokens, and publishes to AWS SQS.

## Features

- **Token Validation**: Validates API tokens stored in AWS SSM Parameter Store
- **Data Validation**: Ensures all required fields are present and valid
- **Timestamp Validation**: Validates Unix timestamp format
- **SQS Integration**: Publishes validated data to AWS SQS queue
- **Health Check**: Provides health check endpoint for load balancers
- **Logging**: Comprehensive logging for monitoring and debugging

## API Endpoints

### Health Check
```
GET /health
```
Returns service health status.

### Process Email
```
POST /process
Content-Type: application/json

{
  "data": {
    "email_subject": "Happy new year!",
    "email_sender": "John doe",
    "email_timestream": "1693561101",
    "email_content": "Just want to say... Happy new year!!!"
  },
  "token": "$DJISA<$#45ex3RtYr"
}
```

**Success Response (200)**:
```json
{
  "status": "success",
  "message": "Email data processed and queued",
  "message_id": "abc123-def456-..."
}
```

**Error Responses**:
- `400 Bad Request`: Invalid data or missing required fields
- `401 Unauthorized`: Invalid or missing token
- `500 Internal Server Error`: Server-side error

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `SQS_QUEUE_URL` | AWS SQS Queue URL | Yes | - |
| `AWS_REGION` | AWS Region | No | `us-west-1` |
| `TOKEN_SSM_PARAMETER` | SSM Parameter Store path for token | No | `/email-service/api-token` |
| `PORT` | Service port | No | `8080` |

## Required IAM Permissions

The service requires the following AWS IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/email-service/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ],
      "Resource": "arn:aws:sqs:*:*:*"
    }
  ]
}
```

## Docker Build and Run

### Build Docker Image
```bash
docker build -t email-processor:latest .
```

### Run Locally
```bash
docker run -d \
  -p 8080:8080 \
  -e AWS_REGION=us-west-1 \
  -e SQS_QUEUE_URL=https://sqs.us-west-1.amazonaws.com/123456789012/your-queue \
  -e TOKEN_SSM_PARAMETER=/email-service/api-token \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  email-processor:latest
```

### Push to ECR
```bash
# Login to ECR
aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-1.amazonaws.com

# Tag image
docker tag email-processor:latest 123456789012.dkr.ecr.us-west-1.amazonaws.com/email-processor:latest

# Push to ECR
docker push 123456789012.dkr.ecr.us-west-1.amazonaws.com/email-processor:latest
```

## Development

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Run Development Server
```bash
export SQS_QUEUE_URL=https://sqs.us-west-1.amazonaws.com/123456789012/your-queue
export AWS_REGION=us-west-1
python app.py
```

### Test the Service
```bash
curl -X POST http://localhost:8080/process \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Test Email",
      "email_sender": "test@example.com",
      "email_timestream": "1693561101",
      "email_content": "This is a test email"
    },
    "token": "your-token-here"
  }'
```

## Data Validation Rules

1. **Token**: Must match the token stored in SSM Parameter Store
2. **Required Fields**: All four fields must be present:
   - `email_subject`
   - `email_sender`
   - `email_timestream`
   - `email_content`
3. **Timestamp**: Must be a valid Unix timestamp between year 2000 and 2100
4. **Non-empty**: All fields must have non-empty values

## Deployment to EKS

See the Kubernetes deployment files in the `k8s/` directory for deployment to Amazon EKS.

## Security Considerations

- Token stored securely in AWS SSM Parameter Store with encryption
- Non-root user in Docker container
- Input validation on all endpoints
- Rate limiting recommended at load balancer level
- TLS/HTTPS termination at load balancer
