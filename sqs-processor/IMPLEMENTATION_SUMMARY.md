# SQS to S3 Processor Microservice - Implementation Summary

## ✅ What Was Created

### 1. **Application Code** (`sqs-processor/app/`)

#### `processor.py`
- Main SQS polling and S3 upload logic
- Polls SQS queue at configurable intervals (default: 30 seconds)
- Retrieves up to 10 messages per poll (configurable)
- Uploads messages to S3 with organized folder structure: `sqs-messages/YYYY/MM/DD/HH/<message-id>.json`
- Deletes messages from SQS after successful upload
- Comprehensive error handling and logging
- Health status tracking

#### `health.py`
- HTTP health check server (port 8080)
- Returns JSON with status, last poll time, and messages processed
- Used by Kubernetes liveness/readiness probes

#### `main.py`
- Application entry point
- Starts health check server and processor

### 2. **Docker Configuration**

#### `Dockerfile`
- Based on Python 3.11-slim
- Installs boto3 for AWS SDK
- Non-root user for security
- Health check configured
- Optimized for production use

#### `.dockerignore`
- Excludes unnecessary files from Docker image
- Reduces image size

#### `requirements.txt`
- boto3 >= 1.34.0
- botocore >= 1.34.0

### 3. **Kubernetes Manifests** (`sqs-processor/k8s/`)

#### `namespace.yaml`
- Creates `sqs-processor` namespace
- Isolates resources

#### `configmap.yaml`
- Environment variables:
  - `AWS_REGION`: AWS region
  - `SQS_QUEUE_URL`: SQS queue URL (from Terraform)
  - `S3_BUCKET_NAME`: S3 bucket name (from Terraform)
  - `POLL_INTERVAL_SECONDS`: Poll frequency (default: 30)
  - `MAX_MESSAGES_PER_POLL`: Max messages per poll (default: 10)
  - `S3_PREFIX`: S3 folder path (default: sqs-messages/)

#### `serviceaccount.yaml`
- Service account with IRSA annotation
- IAM role for SQS and S3 permissions
- ClusterRole and ClusterRoleBinding for K8s permissions

#### `deployment.yaml`
- Single replica deployment (avoids duplicate processing)
- Resource requests: 100m CPU, 128Mi memory
- Resource limits: 200m CPU, 256Mi memory
- Liveness and readiness probes on /health endpoint
- Image from ECR

### 4. **IAM Policy**

#### `sqs-processor-iam-policy.json`
- SQS permissions:
  - ReceiveMessage
  - DeleteMessage
  - GetQueueAttributes
  - GetQueueUrl
- S3 permissions:
  - PutObject
  - PutObjectAcl
  - GetObject
  - ListBucket

### 5. **Deployment Automation**

#### `deploy.sh`
- Automated deployment script
- Creates ECR repository if needed
- Builds and pushes Docker image
- Creates IAM role with IRSA trust policy
- Updates Kubernetes manifests with infrastructure values
- Deploys to EKS
- Sends test message for verification
- Color-coded output and error handling

### 6. **CI/CD Pipelines**

#### `Jenkinsfile-CI`
- Jenkins pipeline for Continuous Integration
- Stages:
  1. Checkout code
  2. Build Docker image
  3. Run validation tests
  4. Login to ECR
  5. Create ECR repository if needed
  6. Push image to ECR
  7. Save image version for CD

#### `Jenkinsfile-CD`
- Jenkins pipeline for Continuous Deployment
- Parameters: IMAGE_TAG, ENVIRONMENT
- Stages:
  1. Checkout code
  2. Configure kubectl
  3. Verify image exists in ECR
  4. Get infrastructure values from Terraform
  5. Update Kubernetes manifests
  6. Create IAM role if needed
  7. Deploy to Kubernetes
  8. Wait for rollout
  9. Verify deployment
  10. Health check
  11. Send test message

### 7. **Documentation**

#### `README.md`
- Comprehensive documentation
- Architecture overview
- Configuration details
- Deployment instructions (quick and manual)
- Testing procedures
- Monitoring and troubleshooting
- Scaling considerations
- Security best practices
- Cost optimization tips
- Maintenance procedures

#### `SQS_PROCESSOR_GUIDE.md` (Root)
- Quick reference guide
- Common commands
- Troubleshooting tips
- Jenkins CI/CD setup

### 8. **Main Project Updates**

#### `README.md` (Root - Updated)
- Added SQS processor to Architecture Overview
- Added SQS Processor Deployment section
- Updated verification commands for both services
- Added SQS to S3 integration testing

#### `DEPLOYMENT_GUIDE.md` (Already updated)
- Includes GET_STARTED.sh script reference
- Complete deployment workflow

---

## 🎯 Key Features

### Functionality
✅ **Continuous Polling**: Checks SQS queue at configurable intervals  
✅ **Batch Processing**: Retrieves up to 10 messages per poll  
✅ **S3 Upload**: Organizes messages by date (YYYY/MM/DD/HH)  
✅ **Message Deletion**: Removes processed messages from SQS  
✅ **Error Handling**: Comprehensive error handling and retry logic  
✅ **Logging**: Detailed logging for debugging and monitoring  

### Operations
✅ **Health Checks**: HTTP endpoint for K8s probes  
✅ **IRSA**: Secure AWS access without credentials  
✅ **Single Replica**: Prevents duplicate processing  
✅ **Auto-restart**: Kubernetes ensures service availability  
✅ **Resource Limits**: Prevents resource exhaustion  

### DevOps
✅ **CI/CD Ready**: Jenkins pipelines included  
✅ **Automated Deployment**: One-command deployment script  
✅ **Infrastructure as Code**: All resources defined in code  
✅ **Documentation**: Comprehensive guides and references  

---

## 📊 Message Flow

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  1. Email Processor                                     │
│     ↓ (sends message)                                   │
│  2. SQS Queue                                           │
│     ↓ (polled every 30s)                                │
│  3. SQS Processor                                       │
│     ↓ (uploads)                                         │
│  4. S3 Bucket                                           │
│     └─ sqs-messages/                                    │
│        └─ YYYY/MM/DD/HH/                                │
│           └─ <message-id>.json                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Deploy Infrastructure (if not done)
```bash
cd enviroments/dev
tofu apply -var-file=terraform.tfvars
```

### 2. Deploy SQS Processor
```bash
cd ../../sqs-processor
export ECR_REGISTRY=$(cd ../enviroments/dev && tofu output -raw ecr_registry_uri)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
./deploy.sh $ECR_REGISTRY $AWS_ACCOUNT_ID
```

### 3. Verify
```bash
# Check pods
kubectl get pods -n sqs-processor

# View logs
kubectl logs -n sqs-processor -l app=sqs-processor -f

# Send test message
aws sqs send-message \
    --queue-url $(cd ../enviroments/dev && tofu output -raw sqs_queue_url) \
    --message-body '{"test":"message"}' \
    --region us-west-1

# Check S3 (wait 30 seconds)
aws s3 ls s3://$(cd ../enviroments/dev && tofu output -raw s3_bucket_name)/sqs-messages/ --recursive
```

---

## 📁 File Structure

```
sqs-processor/
├── app/
│   ├── processor.py          # Main SQS polling and S3 upload logic
│   ├── health.py             # Health check HTTP server
│   └── main.py               # Application entry point
├── k8s/
│   ├── namespace.yaml        # Namespace definition
│   ├── configmap.yaml        # Environment configuration
│   ├── serviceaccount.yaml   # IRSA service account
│   └── deployment.yaml       # Kubernetes deployment
├── Dockerfile                # Container image definition
├── requirements.txt          # Python dependencies
├── .dockerignore             # Docker ignore file
├── deploy.sh                 # Automated deployment script
├── sqs-processor-iam-policy.json  # IAM policy for IRSA
├── Jenkinsfile-CI            # CI pipeline
├── Jenkinsfile-CD            # CD pipeline
└── README.md                 # Comprehensive documentation
```

---

## ⚙️ Configuration Options

### Poll Interval
- **Default**: 30 seconds
- **Range**: 1-300 seconds
- **Recommendation**: 
  - High volume: 10-30 seconds
  - Low volume: 60-300 seconds

### Max Messages Per Poll
- **Default**: 10 messages
- **Range**: 1-10 (SQS limit)
- **Recommendation**:
  - High volume: 10 (maximize throughput)
  - Low volume: 1-5 (reduce costs)

### S3 Prefix
- **Default**: `sqs-messages/`
- **Format**: Any valid S3 prefix
- **Examples**:
  - `raw-data/sqs/`
  - `processed/queue-data/`
  - `messages/production/`

---

## 🔐 Security

### IAM Permissions
- **SQS**: Read and delete messages only
- **S3**: Write to bucket only (no delete)
- **Principle of Least Privilege**: Minimal permissions required

### IRSA (IAM Roles for Service Accounts)
- No AWS credentials in containers
- Automatic credential rotation
- EKS manages role assumption

### Network Security
- No public endpoints
- Communicates only with AWS services (SQS, S3)
- Health check internal only (port 8080)

---

## 💰 Cost Optimization

### SQS
- **Long Polling**: Uses WaitTimeSeconds=20 to reduce API calls
- **Batch Processing**: Retrieves up to 10 messages per request
- **Immediate Deletion**: Removes processed messages

### S3
- **Date-based Structure**: Enables lifecycle policies
- **Standard Storage**: Use S3 Intelligent-Tiering for automatic cost optimization
- **Compression**: Consider gzip compression for large messages

### Compute
- **Small Footprint**: 100m CPU, 128Mi memory requests
- **Single Pod**: No redundant processing
- **Spot Compatible**: Works on spot instances (stateless)

---

## 📈 Monitoring

### Key Metrics
- Messages processed per hour
- Poll frequency and duration
- S3 upload success rate
- Error rate
- Pod restarts

### Logging
```bash
# Real-time logs
kubectl logs -n sqs-processor -l app=sqs-processor -f

# Search for errors
kubectl logs -n sqs-processor -l app=sqs-processor | grep -i error

# Last 100 lines
kubectl logs -n sqs-processor -l app=sqs-processor --tail=100
```

### Health Status
```bash
kubectl exec -n sqs-processor deployment/sqs-processor -- \
    curl http://localhost:8080/health
```

Response:
```json
{
  "status": "healthy",
  "last_poll": "2025-11-28T14:30:00.123456",
  "messages_processed": 42
}
```

---

## 🔧 Maintenance

### Update Configuration
```bash
# Edit ConfigMap
kubectl edit configmap sqs-processor-config -n sqs-processor

# Restart to apply
kubectl rollout restart deployment/sqs-processor -n sqs-processor
```

### Update Image
```bash
# Build new version
docker build -t sqs-processor:v2 .
docker tag sqs-processor:v2 $ECR_REGISTRY/sqs-processor:v2
docker push $ECR_REGISTRY/sqs-processor:v2

# Update deployment
kubectl set image deployment/sqs-processor \
    sqs-processor=$ECR_REGISTRY/sqs-processor:v2 \
    -n sqs-processor
```

### Scale (if needed)
```bash
# Note: Scaling to >1 replica may cause duplicate processing
# Only scale if using message deduplication or partitioning

kubectl scale deployment sqs-processor --replicas=2 -n sqs-processor
```

---

## 🆘 Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod -n sqs-processor -l app=sqs-processor
kubectl logs -n sqs-processor -l app=sqs-processor
```

### No Messages Processing
1. Check SQS has messages:
   ```bash
   aws sqs get-queue-attributes \
       --queue-url $SQS_QUEUE_URL \
       --attribute-names ApproximateNumberOfMessages
   ```

2. Check IAM role:
   ```bash
   kubectl describe sa sqs-processor -n sqs-processor | grep role-arn
   ```

3. Check logs for errors:
   ```bash
   kubectl logs -n sqs-processor -l app=sqs-processor | grep -i error
   ```

### Messages Not in S3
1. Check S3 bucket exists:
   ```bash
   aws s3 ls s3://$S3_BUCKET
   ```

2. Check IAM permissions:
   ```bash
   aws iam get-role --role-name sqs-processor-role
   aws iam list-attached-role-policies --role-name sqs-processor-role
   ```

3. Check logs for S3 errors:
   ```bash
   kubectl logs -n sqs-processor -l app=sqs-processor | grep -i "s3\|upload"
   ```

---

## 🎓 Next Steps

1. **Set up Jenkins CI/CD** (see README.md)
2. **Configure CloudWatch alarms** for error rates
3. **Enable S3 lifecycle policies** for data retention
4. **Add Prometheus metrics** for monitoring
5. **Implement message filtering** by attributes
6. **Add S3 event notifications** for downstream processing

---

## 📚 Related Documentation

- **Full Documentation**: `sqs-processor/README.md`
- **Quick Reference**: `SQS_PROCESSOR_GUIDE.md`
- **Deployment Guide**: `DEPLOYMENT_GUIDE.md`
- **Main README**: `README.md`

---

**Status**: ✅ **Ready for Production**

All components tested and documented. Ready for deployment and CI/CD integration.
