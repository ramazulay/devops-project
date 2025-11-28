# SQS to S3 Processor Microservice

A microservice that continuously polls AWS SQS (Simple Queue Service) for messages and uploads them to S3 (Simple Storage Service).

## Overview

This service:
- **Polls SQS queue** at configurable intervals (default: every 30 seconds)
- **Processes multiple messages** per poll (configurable, default: 10 messages)
- **Uploads messages to S3** in JSON format with organized folder structure
- **Deletes messages** from SQS after successful upload
- **Health check endpoint** for Kubernetes liveness/readiness probes
- **IRSA (IAM Roles for Service Accounts)** for secure AWS access

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  SQS Queue  ──polling──>  SQS Processor  ──upload──>  S3   │
│                              │                              │
│                              │                              │
│                         Health Check                        │
│                         (Port 8080)                         │
└─────────────────────────────────────────────────────────────┘
```

### Message Flow

1. Service polls SQS queue every X seconds (configurable)
2. Receives up to 10 messages per poll (configurable)
3. For each message:
   - Extracts message content and metadata
   - Uploads to S3 with organized path: `sqs-messages/YYYY/MM/DD/HH/<message-id>.json`
   - Deletes message from SQS queue
4. Waits for next poll interval
5. Repeats continuously

### S3 Storage Structure

Messages are stored in S3 with the following structure:

```
s3://bucket-name/
  └── sqs-messages/
      └── 2025/
          └── 11/
              └── 28/
                  └── 14/
                      ├── <message-id-1>.json
                      ├── <message-id-2>.json
                      └── <message-id-3>.json
```

### Message Format in S3

Each JSON file contains:

```json
{
  "message_id": "abc123...",
  "body": "original message body",
  "parsed_body": { ... },  // If body is valid JSON
  "attributes": { ... },
  "message_attributes": { ... },
  "received_at": "2025-11-28T14:30:00.123456",
  "receipt_handle": "..."
}
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `AWS_REGION` | AWS region | `us-west-1` | Yes |
| `SQS_QUEUE_URL` | Full SQS queue URL | - | Yes |
| `S3_BUCKET_NAME` | S3 bucket name | - | Yes |
| `POLL_INTERVAL_SECONDS` | Seconds between polls | `30` | No |
| `MAX_MESSAGES_PER_POLL` | Max messages per poll | `10` | No |
| `S3_PREFIX` | S3 folder prefix | `sqs-messages/` | No |

### Configurable Parameters

#### Poll Interval
- **Purpose**: How often to check SQS for new messages
- **Range**: 1-300 seconds
- **Recommendation**: 
  - High volume: 10-30 seconds
  - Low volume: 60-300 seconds
  - Default (30s) balances responsiveness and cost

#### Max Messages Per Poll
- **Purpose**: Maximum messages to retrieve in each poll
- **Range**: 1-10 (SQS limit)
- **Recommendation**:
  - High volume: 10 (max)
  - Low volume: 1-5
  - Default (10) maximizes throughput

#### S3 Prefix
- **Purpose**: Organize messages in S3
- **Format**: Any valid S3 prefix (folder path)
- **Examples**:
  - `sqs-messages/` (default)
  - `raw-data/sqs/`
  - `processed/queue-data/`

## Deployment

### Prerequisites

1. **Infrastructure deployed** (VPC, EKS, SQS, S3)
2. **kubectl configured** for EKS cluster
3. **Docker** installed locally
4. **AWS CLI** configured with appropriate permissions

### Quick Deployment

```bash
# Get values from Terraform
cd ../enviroments/dev
export ECR_REGISTRY=$(tofu output -raw ecr_registry_uri)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Deploy
cd ../sqs-processor
chmod +x deploy.sh
./deploy.sh $ECR_REGISTRY $AWS_ACCOUNT_ID
```

### Manual Deployment

#### 1. Create ECR Repository

```bash
aws ecr create-repository \
    --repository-name sqs-processor \
    --region us-west-1 \
    --image-scanning-configuration scanOnPush=true
```

#### 2. Build and Push Docker Image

```bash
# Login to ECR
aws ecr get-login-password --region us-west-1 | \
    docker login --username AWS --password-stdin <ECR_REGISTRY>

# Build
docker build -t sqs-processor:latest .

# Tag
docker tag sqs-processor:latest <ECR_REGISTRY>/sqs-processor:latest

# Push
docker push <ECR_REGISTRY>/sqs-processor:latest
```

#### 3. Create IAM Role

```bash
# Get OIDC provider
OIDC_PROVIDER=$(aws eks describe-cluster \
    --name <cluster-name> \
    --query "cluster.identity.oidc.issuer" \
    --output text | sed -e "s/^https:\/\///")

# Create trust policy (see deploy.sh for full policy)
# Create role
aws iam create-role \
    --role-name sqs-processor-role \
    --assume-role-policy-document file://trust-policy.json

# Attach policy
aws iam attach-role-policy \
    --role-name sqs-processor-role \
    --policy-arn arn:aws:iam::<account-id>:policy/SQSProcessorPolicy
```

#### 4. Update Kubernetes Manifests

Edit `k8s/configmap.yaml`:
- Replace `<SQS_QUEUE_URL>` with your SQS queue URL
- Replace `<S3_BUCKET_NAME>` with your S3 bucket name

Edit `k8s/serviceaccount.yaml`:
- Replace `ACCOUNT_ID` with your AWS account ID

Edit `k8s/deployment.yaml`:
- Replace `<ECR_REGISTRY>` with your ECR registry URI

#### 5. Deploy to Kubernetes

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
```

## Testing

### Send Test Message

```bash
# Get SQS queue URL
SQS_QUEUE_URL=$(cd ../enviroments/dev && tofu output -raw sqs_queue_url)

# Send test message
aws sqs send-message \
    --queue-url $SQS_QUEUE_URL \
    --message-body '{"test": "message", "timestamp": "2025-11-28T14:30:00"}' \
    --region us-west-1
```

### Verify Processing

```bash
# Check logs
kubectl logs -n sqs-processor -l app=sqs-processor -f

# Check S3
S3_BUCKET=$(cd ../enviroments/dev && tofu output -raw s3_bucket_name)
aws s3 ls s3://${S3_BUCKET}/sqs-messages/ --recursive

# Download a message
aws s3 cp s3://${S3_BUCKET}/sqs-messages/2025/11/28/14/<message-id>.json -
```

### Health Check

```bash
# From within cluster
kubectl exec -n sqs-processor deployment/sqs-processor -- \
    curl http://localhost:8080/health

# Expected output:
# {"status": "healthy", "last_poll": "2025-11-28T14:30:00", "messages_processed": 42}
```

## Monitoring

### View Logs

```bash
# Real-time logs
kubectl logs -n sqs-processor -l app=sqs-processor -f

# Recent logs
kubectl logs -n sqs-processor -l app=sqs-processor --tail=100
```

### Check Status

```bash
# Deployment status
kubectl get deployment -n sqs-processor

# Pod status
kubectl get pods -n sqs-processor

# Describe pod (troubleshooting)
kubectl describe pod -n sqs-processor -l app=sqs-processor
```

### Metrics

The service logs:
- Number of messages received per poll
- Successfully processed messages
- Errors during processing
- S3 upload confirmations
- SQS deletion confirmations

## Troubleshooting

### Pod Not Starting

**Check pod events:**
```bash
kubectl describe pod -n sqs-processor -l app=sqs-processor
```

**Common issues:**
- Image pull errors → Check ECR permissions
- CrashLoopBackOff → Check logs for application errors
- Pending → Check node resources

### No Messages Being Processed

**Check SQS queue:**
```bash
aws sqs get-queue-attributes \
    --queue-url $SQS_QUEUE_URL \
    --attribute-names ApproximateNumberOfMessages
```

**Check IAM permissions:**
```bash
# Verify service account annotation
kubectl describe sa sqs-processor -n sqs-processor | grep eks.amazonaws.com/role-arn
```

### Messages Not Appearing in S3

**Check S3 permissions:**
```bash
# List bucket contents
aws s3 ls s3://${S3_BUCKET}/sqs-messages/ --recursive

# Check bucket policy
aws s3api get-bucket-policy --bucket ${S3_BUCKET}
```

**Check logs for S3 errors:**
```bash
kubectl logs -n sqs-processor -l app=sqs-processor | grep -i "error\|s3"
```

### Health Check Failing

**Test health endpoint:**
```bash
kubectl exec -n sqs-processor deployment/sqs-processor -- \
    curl -v http://localhost:8080/health
```

**Check port configuration:**
```bash
kubectl get pod -n sqs-processor -o yaml | grep -A 10 "ports:"
```

## Scaling Considerations

### Single Instance Design

This service runs with **replicas: 1** by design to avoid:
- Duplicate message processing
- Race conditions on SQS message visibility
- Unnecessary S3 duplicate writes

### Scaling Options

If you need higher throughput:

1. **Increase poll frequency** (reduce `POLL_INTERVAL_SECONDS`)
2. **Increase max messages** (set `MAX_MESSAGES_PER_POLL` to 10)
3. **Use multiple queues** with separate deployments
4. **Implement message partitioning** by message attributes

### Resource Limits

Current configuration:
- **Requests**: 100m CPU, 128Mi memory
- **Limits**: 200m CPU, 256Mi memory

These are sufficient for processing 10 messages/30 seconds (~1,200 messages/hour).

For higher volumes, increase resources accordingly.

## Security

### IAM Permissions

The service requires:
- **SQS**: ReceiveMessage, DeleteMessage, GetQueueAttributes
- **S3**: PutObject, GetObject, ListBucket

### IRSA (IAM Roles for Service Accounts)

- Uses EKS IRSA for secure AWS access
- No AWS credentials stored in container
- Role assumption managed by EKS

### Network Security

- No public endpoints (except optional NodePort/LoadBalancer for health)
- Communicates only with AWS services
- Health check on port 8080 (internal only)

## Cost Optimization

### SQS Costs

- **Long polling**: Uses WaitTimeSeconds=20 to reduce API calls
- **Batch processing**: Retrieves up to 10 messages per request
- **Immediate deletion**: Removes processed messages to avoid reprocessing

### S3 Costs

- **Organized structure**: Date-based folders for lifecycle policies
- **JSON format**: Human-readable but larger than binary
- Consider: S3 Intelligent-Tiering for automatic cost optimization

### Compute Costs

- **Single pod**: Minimal resource usage
- **Small instance**: Runs on t3.small nodes
- **Spot instances**: Compatible with spot nodes (stateless)

## Maintenance

### Update Configuration

To change poll interval or other settings:

```bash
# Edit ConfigMap
kubectl edit configmap sqs-processor-config -n sqs-processor

# Restart deployment to apply changes
kubectl rollout restart deployment/sqs-processor -n sqs-processor
```

### Update Image

```bash
# Build new image
docker build -t sqs-processor:v2 .
docker tag sqs-processor:v2 <ECR_REGISTRY>/sqs-processor:v2
docker push <ECR_REGISTRY>/sqs-processor:v2

# Update deployment
kubectl set image deployment/sqs-processor \
    sqs-processor=<ECR_REGISTRY>/sqs-processor:v2 \
    -n sqs-processor

# Verify rollout
kubectl rollout status deployment/sqs-processor -n sqs-processor
```

### Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace sqs-processor

# Delete IAM role
aws iam detach-role-policy \
    --role-name sqs-processor-role \
    --policy-arn arn:aws:iam::<account-id>:policy/SQSProcessorPolicy
aws iam delete-role --role-name sqs-processor-role
aws iam delete-policy \
    --policy-arn arn:aws:iam::<account-id>:policy/SQSProcessorPolicy

# Delete ECR repository
aws ecr delete-repository \
    --repository-name sqs-processor \
    --region us-west-1 \
    --force
```

## CI/CD Integration

### Jenkinsfile (CI)

Create `sqs-processor/Jenkinsfile-CI`:

```groovy
// Similar to email processor CI pipeline
// Build → Test → Push to ECR
```

### Jenkinsfile (CD)

Create `sqs-processor/Jenkinsfile-CD`:

```groovy
// Similar to email processor CD pipeline
// Deploy → Verify → Health check
```

## Additional Resources

- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [EKS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

## Project Structure

```
sqs-processor/
├── app/
│   ├── processor.py      # Main SQS polling and S3 upload logic
│   ├── health.py         # Health check HTTP server
│   └── main.py           # Application entry point
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── serviceaccount.yaml
│   └── deployment.yaml
├── Dockerfile
├── requirements.txt
├── deploy.sh             # Automated deployment script
├── sqs-processor-iam-policy.json
└── README.md
```

## Support

For issues or questions:
1. Check logs: `kubectl logs -n sqs-processor -l app=sqs-processor`
2. Review this README
3. Check AWS CloudWatch Logs
4. Verify IAM permissions
5. Test SQS and S3 access manually
