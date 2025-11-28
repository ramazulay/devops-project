#!/bin/bash

# Quick start script for local development
# This script runs the microservice locally with mock AWS services

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up local development environment${NC}"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required but not installed. Please install Python 3."
    exit 1
fi

# Create virtual environment
echo -e "${YELLOW}Creating virtual environment...${NC}"
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate || source venv/Scripts/activate

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Set environment variables for local testing
export AWS_REGION=us-west-1
export SQS_QUEUE_URL=https://sqs.us-west-1.amazonaws.com/123456789012/dev-CP-queue
export TOKEN_SSM_PARAMETER=/email-service/api-token
export PORT=8080

echo -e "${GREEN}Environment setup complete!${NC}"
echo ""
echo "To run the application:"
echo "  python app.py"
echo ""
echo "To run tests:"
echo "  pytest test_app.py -v"
echo ""
echo "To run with coverage:"
echo "  pytest test_app.py --cov=app --cov-report=html"
echo ""
echo "Note: Make sure you have AWS credentials configured for SSM and SQS access"
