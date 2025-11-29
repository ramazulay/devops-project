#!/bin/bash

# Deploy Jenkins on EKS
# This script deploys Jenkins with Docker-in-Docker capability

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Deploying Jenkins on EKS...${NC}"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured. Please configure it first.${NC}"
    exit 1
fi

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${YELLOW}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"

# Update ConfigMap with AWS Account ID
echo -e "${YELLOW}Updating ConfigMap...${NC}"
sed -i.bak "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/configmap.yaml

# Update ServiceAccount with AWS Account ID
sed -i.bak "s|ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" k8s/serviceaccount.yaml

# Create IAM Role for Jenkins (if not exists)
echo -e "${YELLOW}Creating IAM resources...${NC}"

# Check if role exists
if ! aws iam get-role --role-name jenkins-role &> /dev/null; then
    echo "Creating Jenkins IAM role..."
    
    # Get OIDC provider
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
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:jenkins:jenkins",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
    
    # Create role
    aws iam create-role \
        --role-name jenkins-role \
        --assume-role-policy-document file://trust-policy.json
    
    # Create and attach policy
    aws iam create-policy \
        --policy-name JenkinsECRAndEKSPolicy \
        --policy-document file://jenkins-iam-policy.json || true
    
    aws iam attach-role-policy \
        --role-name jenkins-role \
        --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/JenkinsECRAndEKSPolicy
    
    rm trust-policy.json
    
    echo -e "${GREEN}IAM role created successfully${NC}"
else
    echo -e "${GREEN}IAM role already exists${NC}"
fi

# Deploy Jenkins to Kubernetes
echo -e "${YELLOW}Deploying Jenkins to Kubernetes...${NC}"

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/pvc.yaml
kubectl apply -f k8s/deployment.yaml

# Wait for deployment
echo -e "${YELLOW}Waiting for Jenkins to be ready...${NC}"
kubectl rollout status deployment/jenkins -n jenkins --timeout=600s

# Get Jenkins URL
echo -e "${GREEN}Jenkins deployed successfully!${NC}"
echo ""
echo "=== Jenkins Information ==="
kubectl get svc jenkins -n jenkins

echo ""
echo "Getting Load Balancer URL..."
sleep 10
LB_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -n "$LB_URL" ]; then
    echo -e "${GREEN}Jenkins URL: http://${LB_URL}${NC}"
else
    echo -e "${YELLOW}Load Balancer is still provisioning. Run this to get the URL:${NC}"
    echo "kubectl get svc jenkins -n jenkins"
fi

# Get initial admin password
echo ""
echo "=== Initial Admin Password ==="
echo -e "${YELLOW}Waiting for Jenkins to initialize...${NC}"
sleep 30

POD_NAME=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
echo -e "${YELLOW}Getting initial admin password from pod: ${POD_NAME}${NC}"

kubectl exec -n jenkins $POD_NAME -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Password not ready yet. Wait a moment and run: kubectl exec -n jenkins $POD_NAME -- cat /var/jenkins_home/secrets/initialAdminPassword"

echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Access Jenkins at the URL above"
echo "2. Use the initial admin password to log in"
echo "3. Install suggested plugins"
echo "4. Create CI and CD jobs using the Jenkinsfiles"
echo ""
