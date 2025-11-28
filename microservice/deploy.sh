#!/bin/bash

# Deploy Email Processor Microservice to EKS
# Usage: ./deploy.sh <ecr-registry> <aws-account-id>

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -ne 2 ]; then
    echo -e "${RED}Usage: $0 <ecr-registry> <aws-account-id>${NC}"
    echo "Example: $0 123456789012.dkr.ecr.us-west-1.amazonaws.com 123456789012"
    exit 1
fi

ECR_REGISTRY=$1
AWS_ACCOUNT_ID=$2
IMAGE_NAME="email-processor"
IMAGE_TAG="latest"
FULL_IMAGE="${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${GREEN}Starting deployment of Email Processor Microservice${NC}"

# Step 1: Build Docker image
echo -e "${YELLOW}Step 1: Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker image built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build Docker image${NC}"
    exit 1
fi

# Step 2: Tag image for ECR
echo -e "${YELLOW}Step 2: Tagging image for ECR...${NC}"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE}

# Step 3: Login to ECR
echo -e "${YELLOW}Step 3: Logging in to ECR...${NC}"
aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully logged in to ECR${NC}"
else
    echo -e "${RED}✗ Failed to login to ECR${NC}"
    exit 1
fi

# Step 4: Create ECR repository if it doesn't exist
echo -e "${YELLOW}Step 4: Checking ECR repository...${NC}"
aws ecr describe-repositories --repository-names ${IMAGE_NAME} --region us-west-1 2>/dev/null || \
    aws ecr create-repository --repository-name ${IMAGE_NAME} --region us-west-1

# Step 5: Push image to ECR
echo -e "${YELLOW}Step 5: Pushing image to ECR...${NC}"
docker push ${FULL_IMAGE}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image pushed to ECR successfully${NC}"
else
    echo -e "${RED}✗ Failed to push image to ECR${NC}"
    exit 1
fi

# Step 6: Create SSM parameter for token (if not exists)
echo -e "${YELLOW}Step 6: Creating SSM parameter for token...${NC}"
TOKEN='$DJISA<$#45ex3RtYr'
aws ssm put-parameter \
    --name "/email-service/api-token" \
    --value "${TOKEN}" \
    --type "SecureString" \
    --overwrite \
    --region us-west-1 2>/dev/null || echo "Token already exists or created successfully"

# Step 7: Update ConfigMap with correct values
echo -e "${YELLOW}Step 7: Updating Kubernetes ConfigMap...${NC}"
sed -i.bak "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/configmap.yaml
sed -i.bak "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/serviceaccount.yaml

# Step 8: Update Deployment with correct image
echo -e "${YELLOW}Step 8: Updating Deployment configuration...${NC}"
sed -i.bak "s|<ECR_REGISTRY>|${ECR_REGISTRY}|g" k8s/deployment.yaml

# Step 9: Apply Kubernetes manifests
echo -e "${YELLOW}Step 9: Applying Kubernetes manifests...${NC}"

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Kubernetes manifests applied successfully${NC}"
else
    echo -e "${RED}✗ Failed to apply Kubernetes manifests${NC}"
    exit 1
fi

# Step 10: Wait for deployment to be ready
echo -e "${YELLOW}Step 10: Waiting for deployment to be ready...${NC}"
kubectl rollout status deployment/email-processor -n email-processor --timeout=300s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Deployment is ready${NC}"
else
    echo -e "${RED}✗ Deployment failed to become ready${NC}"
    exit 1
fi

# Step 11: Get service information
echo -e "${YELLOW}Step 11: Getting service information...${NC}"
echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo "Service Details:"
kubectl get pods -n email-processor
echo ""
kubectl get svc -n email-processor
echo ""
kubectl get ingress -n email-processor

# Get LoadBalancer URL
echo ""
echo -e "${YELLOW}LoadBalancer URL (may take a few minutes to provision):${NC}"
kubectl get ingress email-processor-ingress -n email-processor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
echo ""
echo -e "${GREEN}Deployment complete! Test the service with:${NC}"
echo "curl -X POST http://<LOAD_BALANCER_URL>/process \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{"
echo "    \"data\": {"
echo "      \"email_subject\": \"Happy new year!\","
echo "      \"email_sender\": \"John doe\","
echo "      \"email_timestream\": \"1693561101\","
echo "      \"email_content\": \"Just want to say... Happy new year!!!\""
echo "    },"
echo "    \"token\": \"\$DJISA<\$#45ex3RtYr\""
echo "  }'"
