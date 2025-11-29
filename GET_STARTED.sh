#!/bin/bash

# ===========================================
# GETTING STARTED - Quick Start Script
# ===========================================
# This script helps you get started with the deployment
# Run this first to check prerequisites and set up your environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║       Email Processor Microservice - Getting Started          ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $2 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
echo ""

# Check AWS CLI
if command_exists aws; then
    print_status "AWS CLI installed" 0
    aws --version
else
    print_status "AWS CLI not installed" 1
    echo -e "${RED}  → Install from: https://aws.amazon.com/cli/${NC}"
fi
echo ""

# Check Terraform/OpenTofu
if command_exists tofu; then
    print_status "OpenTofu installed" 0
    tofu version | head -1
elif command_exists terraform; then
    print_status "Terraform installed" 0
    terraform version | head -1
else
    print_status "Terraform/OpenTofu not installed" 1
    echo -e "${RED}  → Install from: https://opentofu.org/docs/intro/install/${NC}"
fi
echo ""

# Check kubectl
if command_exists kubectl; then
    print_status "kubectl installed" 0
    kubectl version --client --short 2>/dev/null || kubectl version --client
else
    print_status "kubectl not installed" 1
    echo -e "${RED}  → Install from: https://kubernetes.io/docs/tasks/tools/${NC}"
fi
echo ""

# Check Python
if command_exists python3; then
    print_status "Python 3 installed" 0
    python3 --version
else
    print_status "Python 3 not installed" 1
    echo -e "${RED}  → Install from: https://www.python.org/downloads/${NC}"
fi
echo ""

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if aws sts get-caller-identity >/dev/null 2>&1; then
    print_status "AWS credentials configured" 0
    echo ""
    echo "AWS Account Information:"
    aws sts get-caller-identity
else
    print_status "AWS credentials not configured" 1
    echo -e "${RED}  → Run: aws configure${NC}"
fi
echo ""

# Get AWS Account ID and Region
if aws sts get-caller-identity >/dev/null 2>&1; then
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export AWS_REGION=$(aws configure get region || echo "us-west-1")
    export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    echo -e "${GREEN}Environment Variables:${NC}"
    echo "  AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
    echo "  AWS_REGION=${AWS_REGION}"
    echo "  ECR_REGISTRY=${ECR_REGISTRY}"
    echo ""
    
    # Save to .env file
    cat > .env <<EOF
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
export AWS_REGION=${AWS_REGION}
export ECR_REGISTRY=${ECR_REGISTRY}
EOF
    echo -e "${GREEN}✓${NC} Environment variables saved to .env file"
    echo -e "  Run: ${BLUE}source .env${NC} to load them"
fi
echo ""
echo -e "${GREEN}Good luck! 🚀${NC}"
echo ""
