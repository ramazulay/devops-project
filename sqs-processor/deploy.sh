#!/bin/bash

# Deploy SQS Processor Microservice
# This script builds, pushes, and deploys the SQS processor to EKS

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║       SQS to S3 Processor - Deployment Script                 ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if ECR_REGISTRY and AWS_ACCOUNT_ID are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}Usage: $0 <ECR_REGISTRY> <AWS_ACCOUNT_ID>${NC}"
    echo ""
    echo "Example:"
    echo "  $0 123456789012.dkr.ecr.us-west-1.amazonaws.com 123456789012"
    echo ""
    echo "Get these values from Terraform:"
    echo "  cd ../enviroments/dev"
    echo "  export ECR_REGISTRY=\$(tofu output -raw ecr_registry_uri)"
    echo "  export AWS_ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)"
    exit 1
fi

ECR_REGISTRY=$1
AWS_ACCOUNT_ID=$2
IMAGE_NAME="sqs-processor"
IMAGE_TAG="${3:-latest}"
FULL_IMAGE="${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${YELLOW}Configuration:${NC}"
echo "  ECR Registry: ${ECR_REGISTRY}"
echo "  AWS Account: ${AWS_ACCOUNT_ID}"
echo "  Image: ${FULL_IMAGE}"
echo ""

# Get AWS region from ECR registry
AWS_REGION=$(echo $ECR_REGISTRY | cut -d'.' -f4)
echo -e "${YELLOW}Detected AWS Region: ${AWS_REGION}${NC}"
echo ""

# Check if kubectl is configured
echo -e "${YELLOW}Checking kubectl configuration...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured. Please configure it first.${NC}"
    echo "Run: aws eks update-kubeconfig --name <cluster-name> --region ${AWS_REGION}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl is configured${NC}"
echo ""

# Get infrastructure values from Terraform
echo -e "${YELLOW}Getting infrastructure values from Terraform...${NC}"
cd ../enviroments/dev

if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform state not found. Please deploy infrastructure first.${NC}"
    exit 1
fi

SQS_QUEUE_URL=$(tofu output -raw sqs_queue_url 2>/dev/null || terraform output -raw sqs_queue_url 2>/dev/null)
S3_BUCKET_NAME=$(tofu output -raw s3_bucket_name 2>/dev/null || terraform output -raw s3_bucket_name 2>/dev/null)
EKS_CLUSTER=$(tofu output -raw eks_cluster_id 2>/dev/null || terraform output -raw eks_cluster_id 2>/dev/null)

if [ -z "$SQS_QUEUE_URL" ] || [ -z "$S3_BUCKET_NAME" ]; then
    echo -e "${RED}Error: Could not retrieve SQS Queue URL or S3 Bucket Name from Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Infrastructure values retrieved:${NC}"
echo "  SQS Queue URL: ${SQS_QUEUE_URL}"
echo "  S3 Bucket: ${S3_BUCKET_NAME}"
echo "  EKS Cluster: ${EKS_CLUSTER}"
echo ""

cd ../../sqs-processor

# Check if ECR repository exists, create if not
echo -e "${YELLOW}Checking ECR repository...${NC}"
if ! aws ecr describe-repositories --repository-names ${IMAGE_NAME} --region ${AWS_REGION} &> /dev/null; then
    echo -e "${YELLOW}Creating ECR repository: ${IMAGE_NAME}${NC}"
    aws ecr create-repository \
        --repository-name ${IMAGE_NAME} \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true
    echo -e "${GREEN}✓ ECR repository created${NC}"
else
    echo -e "${GREEN}✓ ECR repository exists${NC}"
fi
echo ""

# Login to ECR
echo -e "${YELLOW}Logging in to ECR...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
echo -e "${GREEN}✓ Logged in to ECR${NC}"
echo ""

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE}
echo -e "${GREEN}✓ Docker image built${NC}"
echo ""

# Push to ECR
echo -e "${YELLOW}Pushing image to ECR...${NC}"
docker push ${FULL_IMAGE}
echo -e "${GREEN}✓ Image pushed to ECR${NC}"
echo ""

# Create IAM role for service account (if not exists)
echo -e "${YELLOW}Setting up IAM role for service account...${NC}"
ROLE_NAME="sqs-processor-role"

if ! aws iam get-role --role-name ${ROLE_NAME} &> /dev/null; then
    echo "Creating IAM role..."
    
    # Get OIDC provider
    OIDC_PROVIDER=$(aws eks describe-cluster --name ${EKS_CLUSTER} --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
    
    # Create trust policy
    cat > /tmp/trust-policy.json <<EOF
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
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:sqs-processor:sqs-processor",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
    
    # Create role
    aws iam create-role \
        --role-name ${ROLE_NAME} \
        --assume-role-policy-document file:///tmp/trust-policy.json
    
    # Create and attach policy
    POLICY_NAME="SQSProcessorPolicy"
    POLICY_ARN=$(aws iam create-policy \
        --policy-name ${POLICY_NAME} \
        --policy-document file://sqs-processor-iam-policy.json \
        --query 'Policy.Arn' \
        --output text 2>/dev/null || echo "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}")
    
    aws iam attach-role-policy \
        --role-name ${ROLE_NAME} \
        --policy-arn ${POLICY_ARN}
    
    rm /tmp/trust-policy.json
    
    echo -e "${GREEN}✓ IAM role created${NC}"
else
    echo -e "${GREEN}✓ IAM role already exists${NC}"
fi
echo ""

# Update Kubernetes manifests
echo -e "${YELLOW}Updating Kubernetes manifests...${NC}"

# Update ConfigMap
sed -i.bak "s|<SQS_QUEUE_URL>|${SQS_QUEUE_URL}|g" k8s/configmap.yaml
sed -i.bak "s|<S3_BUCKET_NAME>|${S3_BUCKET_NAME}|g" k8s/configmap.yaml
sed -i.bak "s|us-west-1|${AWS_REGION}|g" k8s/configmap.yaml

# Update ServiceAccount
sed -i.bak "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/serviceaccount.yaml

# Update Deployment
sed -i.bak "s|<ECR_REGISTRY>|${ECR_REGISTRY}|g" k8s/deployment.yaml

echo -e "${GREEN}✓ Manifests updated${NC}"
echo ""

# Deploy to Kubernetes
echo -e "${YELLOW}Deploying to Kubernetes...${NC}"

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml

echo -e "${GREEN}✓ Deployed to Kubernetes${NC}"
echo ""

# Wait for deployment
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/sqs-processor -n sqs-processor --timeout=300s

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}SQS Processor Deployed Successfully! 🎉${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Deployment Information:"
kubectl get all -n sqs-processor
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Check logs:"
echo "   kubectl logs -n sqs-processor -l app=sqs-processor -f"
echo ""
echo "2. Send test message to SQS:"
echo "   aws sqs send-message --queue-url ${SQS_QUEUE_URL} --message-body '{\"test\":\"message\"}' --region ${AWS_REGION}"
echo ""
echo "3. Verify message in S3:"
echo "   aws s3 ls s3://${S3_BUCKET_NAME}/sqs-messages/ --recursive"
echo ""
echo "4. Check health:"
echo "   kubectl exec -n sqs-processor deployment/sqs-processor -- curl http://localhost:8080/health"
echo ""
