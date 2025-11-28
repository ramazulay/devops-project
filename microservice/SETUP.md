# Email Processor Microservice - Setup and Deployment Guide

## Prerequisites

1. **AWS Account** with access to:
   - EKS Cluster (already created via Terraform)
   - ECR Repository
   - SQS Queue (already created via Terraform)
   - SSM Parameter Store
   - IAM permissions

2. **Tools Installed**:
   - Docker
   - kubectl
   - AWS CLI
   - Helm (optional, for AWS Load Balancer Controller)

3. **Environment Variables**:
   ```bash
   export AWS_ACCOUNT_ID=<your-account-id>
   export AWS_REGION=us-west-1
   export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
   ```

## Step 1: Configure EKS Cluster Access

```bash
# Update kubeconfig
aws eks update-kubeconfig --name dev-CP-EKS-CLUSTER --region us-west-1

# Verify cluster access
kubectl get nodes
```

## Step 2: Install AWS Load Balancer Controller (if not already installed)

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-CP-EKS-CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## Step 3: Create IAM Role for Service Account (IRSA)

Create an IAM policy file `email-processor-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:us-west-1:ACCOUNT_ID:parameter/email-service/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:us-west-1:ACCOUNT_ID:dev-CP-queue"
    }
  ]
}
```

Replace `ACCOUNT_ID` with your AWS account ID, then create the policy and role:

```bash
# Create IAM policy
aws iam create-policy \
  --policy-name EmailProcessorServicePolicy \
  --policy-document file://email-processor-policy.json

# Get OIDC provider URL
OIDC_PROVIDER=$(aws eks describe-cluster --name dev-CP-EKS-CLUSTER --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:email-processor:email-processor-sa",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name email-processor-role \
  --assume-role-policy-document file://trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name email-processor-role \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/EmailProcessorServicePolicy
```

## Step 4: Store API Token in SSM Parameter Store

```bash
# Create secure parameter for token
aws ssm put-parameter \
  --name "/email-service/api-token" \
  --value '$DJISA<$#45ex3RtYr' \
  --type "SecureString" \
  --description "API token for email processor service" \
  --region us-west-1
```

## Step 5: Build and Push Docker Image

```bash
# Navigate to microservice directory
cd microservice

# Build Docker image
docker build -t email-processor:latest .

# Login to ECR
aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Create ECR repository
aws ecr create-repository --repository-name email-processor --region us-west-1

# Tag and push image
docker tag email-processor:latest ${ECR_REGISTRY}/email-processor:latest
docker push ${ECR_REGISTRY}/email-processor:latest
```

## Step 6: Update Kubernetes Manifests

Update the following files with your actual values:

1. **k8s/configmap.yaml**: Replace `ACCOUNT_ID` with your AWS account ID
2. **k8s/serviceaccount.yaml**: Replace `ACCOUNT_ID` with your AWS account ID
3. **k8s/deployment.yaml**: Replace `<ECR_REGISTRY>` with your ECR registry URL

Or use sed:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

sed -i "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/configmap.yaml
sed -i "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/serviceaccount.yaml
sed -i "s|<ECR_REGISTRY>|${ECR_REGISTRY}|g" k8s/deployment.yaml
```

## Step 7: Deploy to Kubernetes

```bash
# Apply manifests in order
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress.yaml

# Check deployment status
kubectl get pods -n email-processor
kubectl rollout status deployment/email-processor -n email-processor
```

## Step 8: Get Load Balancer URL

```bash
# Wait for load balancer to provision (may take 2-3 minutes)
kubectl get ingress email-processor-ingress -n email-processor

# Get the URL
export LB_URL=$(kubectl get ingress email-processor-ingress -n email-processor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Load Balancer URL: http://${LB_URL}"
```

## Step 9: Test the Service

### Test Health Endpoint
```bash
curl http://${LB_URL}/health
```

### Test Email Processing (Valid Request)
```bash
curl -X POST http://${LB_URL}/process \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Happy new year!",
      "email_sender": "John doe",
      "email_timestream": "1693561101",
      "email_content": "Just want to say... Happy new year!!!"
    },
    "token": "$DJISA<$#45ex3RtYr"
  }'
```

Expected response:
```json
{
  "status": "success",
  "message": "Email data processed and queued",
  "message_id": "abc123-def456-..."
}
```

### Run All Tests
```bash
chmod +x test.sh
./test.sh http://${LB_URL}
```

## Step 10: Verify SQS Messages

```bash
# Get queue URL
export QUEUE_URL=$(aws sqs get-queue-url --queue-name dev-CP-queue --region us-west-1 --query 'QueueUrl' --output text)

# Receive messages from queue
aws sqs receive-message \
  --queue-url ${QUEUE_URL} \
  --region us-west-1 \
  --max-number-of-messages 10
```

## Monitoring and Logs

### View Pod Logs
```bash
kubectl logs -f deployment/email-processor -n email-processor
```

### View All Pods
```bash
kubectl get pods -n email-processor -w
```

### Describe Pod (for troubleshooting)
```bash
kubectl describe pod <pod-name> -n email-processor
```

### Check HPA Status
```bash
kubectl get hpa -n email-processor
```

## Automated Deployment

Use the provided deployment script:

```bash
chmod +x deploy.sh
./deploy.sh ${ECR_REGISTRY} ${AWS_ACCOUNT_ID}
```

## Cleanup

To remove the deployment:

```bash
kubectl delete namespace email-processor
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n email-processor
kubectl logs <pod-name> -n email-processor
```

### Load balancer not provisioning
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress events
kubectl describe ingress email-processor-ingress -n email-processor
```

### Permission issues
- Verify IAM role is correctly associated with service account
- Check IAM policy permissions
- Verify OIDC provider is configured for the EKS cluster

### SQS message not arriving
- Check service logs for errors
- Verify SQS queue URL in ConfigMap
- Check IAM permissions for SQS
- Verify network connectivity from EKS to SQS

## Architecture Overview

```
Internet → ALB (Ingress) → Service → Pods (email-processor)
                                      ↓
                                    SQS Queue
                                      ↓
                                 SSM Parameter Store (Token)
```

## API Response Codes

- **200**: Success - Email data processed and queued
- **400**: Bad Request - Invalid data or missing required fields
- **401**: Unauthorized - Invalid or missing token
- **500**: Internal Server Error - Server-side error

## Security Best Practices

1. ✅ Token stored encrypted in SSM Parameter Store
2. ✅ Container runs as non-root user
3. ✅ IAM role for service account (IRSA) - no hardcoded credentials
4. ✅ Least privilege IAM permissions
5. ✅ TLS termination at load balancer (configure ALB listener for HTTPS)
6. ✅ Network policies (recommended to add)
7. ✅ Resource limits set on pods
8. ✅ Health checks configured

## Next Steps

1. Configure HTTPS on ALB with ACM certificate
2. Add API rate limiting at ALB or application level
3. Set up CloudWatch alarms for monitoring
4. Configure log aggregation (CloudWatch Logs, ELK stack)
5. Add request tracing (X-Ray)
6. Implement CI/CD pipeline
