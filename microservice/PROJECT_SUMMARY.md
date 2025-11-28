# Email Processing Microservice - Complete Solution

## 📋 Overview

A production-ready Python microservice that:
- ✅ Receives REST API requests from an Application Load Balancer (ALB)
- ✅ Validates API tokens stored securely in AWS SSM Parameter Store
- ✅ Validates request data with 4 required fields
- ✅ Validates Unix timestamp format
- ✅ Publishes validated messages to AWS SQS queue
- ✅ Runs in Docker containers on Amazon EKS
- ✅ Auto-scales based on CPU/memory usage
- ✅ Includes comprehensive tests and health checks

## 🏗️ Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│  Application Load Balancer      │
│  (ALB via Ingress Controller)   │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  Kubernetes Service (ClusterIP) │
└──────┬──────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│  Email Processor Pods (2-10 replicas)│
│  - Flask REST API                    │
│  - Token validation                  │
│  - Data validation                   │
│  - Gunicorn workers                  │
└──────┬─────────────────┬─────────────┘
       │                 │
       │                 ▼
       │         ┌─────────────────┐
       │         │  SSM Parameter  │
       │         │  Store (Token)  │
       │         └─────────────────┘
       │
       ▼
┌─────────────────┐
│   SQS Queue     │
│  (+ DLQ)        │
└─────────────────┘
```

## 📁 Project Structure

```
microservice/
├── app.py                      # Main application code
├── requirements.txt            # Python dependencies
├── requirements-dev.txt        # Development dependencies
├── Dockerfile                  # Container image definition
├── .dockerignore              # Docker ignore patterns
├── test_app.py                # Unit tests
├── README.md                  # API documentation
├── SETUP.md                   # Deployment guide
├── deploy.sh                  # Automated deployment script
├── test.sh                    # API testing script
├── setup-local.sh             # Local dev setup script
└── k8s/                       # Kubernetes manifests
    ├── namespace.yaml         # Namespace definition
    ├── configmap.yaml         # Configuration
    ├── serviceaccount.yaml    # Service account + RBAC
    ├── deployment.yaml        # Deployment + Service
    ├── ingress.yaml           # ALB ingress
    └── hpa.yaml              # Horizontal Pod Autoscaler
```

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
cd microservice
chmod +x deploy.sh

# Get your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.us-west-1.amazonaws.com

# Run deployment
./deploy.sh ${ECR_REGISTRY} ${AWS_ACCOUNT_ID}
```

### Option 2: Manual Step-by-Step

See [SETUP.md](SETUP.md) for detailed manual deployment instructions.

### Option 3: Local Development

```bash
cd microservice
chmod +x setup-local.sh
./setup-local.sh

# Activate virtual environment
source venv/bin/activate  # Linux/Mac
# or
source venv/Scripts/activate  # Windows Git Bash

# Run application
python app.py

# Run tests
pytest test_app.py -v
```

## 🔌 API Endpoints

### Health Check
```bash
GET /health
```

**Response (200)**:
```json
{
  "status": "healthy",
  "service": "email-processor",
  "timestamp": "2025-11-26T10:30:00.000000"
}
```

### Process Email
```bash
POST /process
Content-Type: application/json
```

**Request**:
```json
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
  "message_id": "abc123-def456-789"
}
```

**Error Responses**:
- `400`: Missing/invalid data fields or invalid timestamp
- `401`: Invalid or missing token
- `500`: Internal server error

## ✅ Validation Rules

### 1. Token Validation
- Token must be provided in the request
- Token must match the value stored in SSM Parameter Store (`/email-service/api-token`)
- Invalid token returns 401 Unauthorized

### 2. Data Field Validation
All 4 fields are required and must not be empty:
- ✅ `email_subject`
- ✅ `email_sender`
- ✅ `email_timestream`
- ✅ `email_content`

### 3. Timestamp Validation
- Must be a valid Unix timestamp (integer)
- Must be in reasonable range (year 2000 to 2100)
- Format: `"1693561101"` (string or number)

## 🔒 Security Features

1. **Token Security**
   - Stored encrypted in AWS SSM Parameter Store
   - Retrieved at runtime (never hardcoded)
   - Uses SecureString parameter type

2. **Container Security**
   - Runs as non-root user (UID 1000)
   - No privilege escalation
   - Drops all capabilities
   - Read-only root filesystem (can be enabled)

3. **IAM Security**
   - Uses IAM Roles for Service Accounts (IRSA)
   - No hardcoded AWS credentials
   - Least privilege permissions
   - Only grants access to specific SSM parameters and SQS queue

4. **Network Security**
   - TLS termination at ALB
   - ClusterIP service (internal only)
   - Can add Network Policies for pod-to-pod traffic

## 📊 Monitoring & Observability

### Logs
```bash
# View real-time logs
kubectl logs -f deployment/email-processor -n email-processor

# View logs from specific pod
kubectl logs <pod-name> -n email-processor
```

### Metrics
```bash
# Check HPA status
kubectl get hpa -n email-processor

# View pod resource usage
kubectl top pods -n email-processor
```

### Health Checks
- **Liveness Probe**: `/health` endpoint (every 10s)
- **Readiness Probe**: `/health` endpoint (every 5s)
- **Startup Grace Period**: 30 seconds

## 🧪 Testing

### Run Unit Tests
```bash
cd microservice
pip install -r requirements-dev.txt
pytest test_app.py -v
```

### Run with Coverage
```bash
pytest test_app.py --cov=app --cov-report=html
```

### API Integration Tests
```bash
chmod +x test.sh

# Get load balancer URL
export LB_URL=$(kubectl get ingress email-processor-ingress -n email-processor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Run tests
./test.sh http://${LB_URL}
```

### Test Scenarios Covered
1. ✅ Valid request processing
2. ✅ Missing token
3. ✅ Invalid token
4. ✅ Missing required fields
5. ✅ Empty field values
6. ✅ Invalid timestamp format
7. ✅ Timestamp out of range
8. ✅ Invalid JSON payload

## 📈 Scalability

### Horizontal Pod Autoscaler (HPA)
- **Min Replicas**: 2
- **Max Replicas**: 10
- **Scale Up**: When CPU > 70% or Memory > 80%
- **Scale Down**: Gradual (50% every 5 minutes)

### Resource Allocation
Per pod:
- **CPU Request**: 250m (0.25 cores)
- **CPU Limit**: 500m (0.5 cores)
- **Memory Request**: 256Mi
- **Memory Limit**: 512Mi

### Gunicorn Workers
- **Workers**: 4 per pod
- **Threads**: 2 per worker
- **Total Capacity**: 8 concurrent requests per pod

## 🔧 Configuration

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_REGION` | AWS region | `us-west-1` |
| `SQS_QUEUE_URL` | SQS queue URL | Required |
| `TOKEN_SSM_PARAMETER` | SSM parameter path | `/email-service/api-token` |
| `PORT` | Application port | `8080` |

### ConfigMap (k8s/configmap.yaml)
```yaml
data:
  sqs_queue_url: "https://sqs.us-west-1.amazonaws.com/ACCOUNT_ID/dev-CP-queue"
  aws_region: "us-west-1"
```

## 📦 Infrastructure Requirements

### AWS Resources (Created by Terraform)
- ✅ EKS Cluster
- ✅ VPC with public/private subnets
- ✅ SQS Queue (with DLQ)
- ✅ S3 Bucket
- ✅ Security Groups
- ✅ IAM Roles

### Additional Resources (Manual Setup)
- ECR Repository (for Docker images)
- SSM Parameter (for token)
- IAM Role for Service Account (IRSA)
- AWS Load Balancer Controller (for ALB)

## 🎯 Production Checklist

Before going to production:

- [ ] Configure HTTPS on ALB with ACM certificate
- [ ] Set up CloudWatch Logs integration
- [ ] Configure CloudWatch Alarms
- [ ] Add API rate limiting
- [ ] Implement request tracing (X-Ray)
- [ ] Set up CI/CD pipeline
- [ ] Configure backup and disaster recovery
- [ ] Add Kubernetes Network Policies
- [ ] Enable container image scanning
- [ ] Set up centralized logging (ELK/CloudWatch)
- [ ] Configure monitoring dashboards
- [ ] Document runbooks for operations

## 🐛 Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n email-processor
kubectl logs <pod-name> -n email-processor
```

### Permission denied errors
- Check IAM role annotation on ServiceAccount
- Verify IAM policy permissions
- Confirm OIDC provider is configured

### SQS messages not arriving
- Check application logs for errors
- Verify SQS queue URL in ConfigMap
- Test IAM permissions manually

### Load balancer not creating
```bash
# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress status
kubectl describe ingress email-processor-ingress -n email-processor
```

## 📚 Additional Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 🤝 Contributing

1. Follow PEP 8 style guidelines
2. Add tests for new features
3. Update documentation
4. Use meaningful commit messages

## 📄 License

This project is part of the DevOps infrastructure project.

## 🎉 Summary

This microservice provides a complete, production-ready solution for:
- ✅ REST API with validation
- ✅ Secure token management
- ✅ SQS integration
- ✅ Container orchestration
- ✅ Auto-scaling
- ✅ Health monitoring
- ✅ Comprehensive testing
- ✅ Easy deployment

All components follow AWS and Kubernetes best practices for security, scalability, and reliability.
