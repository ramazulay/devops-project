#!/bin/bash

# Test script for the Email Processor Microservice
# Usage: ./test.sh <service-url>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <service-url>${NC}"
    echo "Example: $0 http://localhost:8080"
    exit 1
fi

SERVICE_URL=$1
TOKEN='$DJISA<$#45ex3RtYr'

echo -e "${GREEN}Testing Email Processor Microservice${NC}"
echo "Service URL: ${SERVICE_URL}"
echo ""

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" "${SERVICE_URL}/health"
echo ""

# Test 2: Valid Request
echo -e "${YELLOW}Test 2: Valid Request${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "${SERVICE_URL}/process" \
  -H "Content-Type: application/json" \
  -d "{
    \"data\": {
      \"email_subject\": \"Happy new year!\",
      \"email_sender\": \"John doe\",
      \"email_timestream\": \"1693561101\",
      \"email_content\": \"Just want to say... Happy new year!!!\"
    },
    \"token\": \"${TOKEN}\"
  }"
echo ""

# Test 3: Missing Token
echo -e "${YELLOW}Test 3: Missing Token (should fail with 401)${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "${SERVICE_URL}/process" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Test",
      "email_sender": "Test",
      "email_timestream": "1693561101",
      "email_content": "Test"
    }
  }'
echo ""

# Test 4: Invalid Token
echo -e "${YELLOW}Test 4: Invalid Token (should fail with 401)${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "${SERVICE_URL}/process" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Test",
      "email_sender": "Test",
      "email_timestream": "1693561101",
      "email_content": "Test"
    },
    "token": "invalid-token"
  }'
echo ""

# Test 5: Missing Required Field
echo -e "${YELLOW}Test 5: Missing Required Field (should fail with 400)${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "${SERVICE_URL}/process" \
  -H "Content-Type: application/json" \
  -d "{
    \"data\": {
      \"email_subject\": \"Test\",
      \"email_sender\": \"Test\",
      \"email_timestream\": \"1693561101\"
    },
    \"token\": \"${TOKEN}\"
  }"
echo ""

# Test 6: Invalid Timestamp
echo -e "${YELLOW}Test 6: Invalid Timestamp (should fail with 400)${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "${SERVICE_URL}/process" \
  -H "Content-Type: application/json" \
  -d "{
    \"data\": {
      \"email_subject\": \"Test\",
      \"email_sender\": \"Test\",
      \"email_timestream\": \"not-a-timestamp\",
      \"email_content\": \"Test\"
    },
    \"token\": \"${TOKEN}\"
  }"
echo ""

# Test 7: Empty Field
echo -e "${YELLOW}Test 7: Empty Field (should fail with 400)${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "${SERVICE_URL}/process" \
  -H "Content-Type: application/json" \
  -d "{
    \"data\": {
      \"email_subject\": \"\",
      \"email_sender\": \"Test\",
      \"email_timestream\": \"1693561101\",
      \"email_content\": \"Test\"
    },
    \"token\": \"${TOKEN}\"
  }"
echo ""

echo -e "${GREEN}All tests completed!${NC}"
