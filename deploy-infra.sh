#!/bin/bash

# ===========================================
# Infrastructure Deployment Script
# ===========================================
# This script deploys the complete AWS infrastructure:
# - VPC, Subnets, Internet Gateway, Route Tables
# - EKS Cluster with Node Groups
# - ECR Repository
# - SQS Queue with DLQ
# - S3 Bucket with versioning
# - IAM Roles and Policies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║           Infrastructure Deployment Script                     ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running from project root
if [ ! -d "enviroments/dev" ]; then
    echo -e "${RED}Error: Please run this script from the project root directory${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
echo ""

# Check Terraform/OpenTofu
if command -v tofu &> /dev/null; then
    TERRAFORM_CMD="tofu"
    echo -e "${GREEN}✓ OpenTofu found${NC}"
    tofu version | head -1
elif command -v terraform &> /dev/null; then
    TERRAFORM_CMD="terraform"
    echo -e "${GREEN}✓ Terraform found${NC}"
    terraform version | head -1
else
    echo -e "${RED}✗ Terraform/OpenTofu not found${NC}"
    echo "Please install from: https://opentofu.org/docs/intro/install/"
    exit 1
fi
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found${NC}"
    echo "Please install from: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI found${NC}"
aws --version
echo ""

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials configured${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠ kubectl not found - you'll need it later to connect to EKS${NC}"
    echo "Install from: https://kubernetes.io/docs/tasks/tools/"
    echo ""
fi

# Navigate to environment directory
cd enviroments/dev

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Current Configuration:${NC}"
echo ""
cat terraform.tfvars
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Ask for confirmation
read -p "$(echo -e ${YELLOW}Do you want to proceed with infrastructure deployment? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 0
fi
echo ""

# Initialize Terraform
echo -e "${YELLOW}Step 1/4: Initializing Terraform...${NC}"
$TERRAFORM_CMD init
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Terraform initialization failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Validate configuration
echo -e "${YELLOW}Step 2/4: Validating configuration...${NC}"
$TERRAFORM_CMD validate
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Configuration validation failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Configuration is valid${NC}"
echo ""

# Plan infrastructure
echo -e "${YELLOW}Step 3/4: Planning infrastructure changes...${NC}"
$TERRAFORM_CMD plan -var-file=terraform.tfvars -out=tfplan
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Terraform plan failed${NC}"
    exit 1
fi
echo ""
echo -e "${GREEN}✓ Plan created successfully${NC}"
echo ""

# Ask for final confirmation
read -p "$(echo -e ${YELLOW}Review the plan above. Apply these changes? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    rm -f tfplan
    exit 0
fi
echo ""

# Apply infrastructure
echo -e "${YELLOW}Step 4/4: Deploying infrastructure...${NC}"
echo -e "${CYAN}This will take approximately 15-20 minutes...${NC}"
echo ""

$TERRAFORM_CMD apply tfplan
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Infrastructure deployment failed${NC}"
    rm -f tfplan
    exit 1
fi

rm -f tfplan

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Infrastructure Deployed Successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Get outputs
echo -e "${YELLOW}Infrastructure Outputs:${NC}"
echo ""
$TERRAFORM_CMD output

# Save outputs to file
echo ""
echo -e "${YELLOW}Saving outputs to infrastructure-outputs.env...${NC}"
cat > ../../infrastructure-outputs.env <<EOF
# Infrastructure Outputs
# Generated on: $(date)
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
export AWS_REGION=$($TERRAFORM_CMD output -raw region)
export EKS_CLUSTER=$($TERRAFORM_CMD output -raw eks_cluster_id)
export ECR_REGISTRY=$($TERRAFORM_CMD output -raw ecr_registry_uri)
export SQS_QUEUE_URL=$($TERRAFORM_CMD output -raw sqs_queue_url)
export S3_BUCKET=$($TERRAFORM_CMD output -raw s3_bucket_name)
EOF

echo -e "${GREEN}✓ Outputs saved to infrastructure-outputs.env${NC}"
echo ""

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl for EKS...${NC}"
EKS_CLUSTER=$($TERRAFORM_CMD output -raw eks_cluster_id)
AWS_REGION=$($TERRAFORM_CMD output -raw region)

if command -v kubectl &> /dev/null; then
    aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ kubectl configured successfully${NC}"
        echo ""
        echo -e "${YELLOW}Verifying EKS cluster...${NC}"
        kubectl get nodes
        echo ""
        kubectl get pods -A
        echo ""
    else
        echo -e "${RED}✗ Failed to configure kubectl${NC}"
        echo "You can configure it manually later with:"
        echo "  aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION"
    fi
else
    echo -e "${YELLOW}⚠ kubectl not found. Install it and run:${NC}"
    echo "  aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION"
fi
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo ""
echo -e "${CYAN}1. Load environment variables:${NC}"
echo "   source infrastructure-outputs.env"
echo ""
echo -e "${CYAN}2. Deploy Jenkins (optional):${NC}"
echo "   cd jenkins"
echo "   ./deploy-jenkins.sh"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Infrastructure deployment complete! 🎉${NC}"
echo ""
