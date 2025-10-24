#!/bin/bash

# Simple cURL testing script for Bojang API
# Usage: ./test_with_curl.sh [BASE_URL]

BASE_URL=${1:-"http://localhost:3000"}

echo "Testing Bojang API at: $BASE_URL"
echo "======================================"

# Test 1: Health Check
echo "1. Testing Health Check..."
curl -s "$BASE_URL/health" | python3 -m json.tool
echo -e "\n"

# Test 2: Register User
echo "2. Testing User Registration..."
curl -s -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "testpass123",
    "displayName": "Test User"
  }' | python3 -m json.tool
echo -e "\n"

# Test 3: Login User
echo "3. Testing User Login..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpass123"
  }')

echo "$LOGIN_RESPONSE" | python3 -m json.tool

# Extract token for authenticated requests
TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))" 2>/dev/null)
echo "Extracted token: ${TOKEN:0:20}..."
echo -e "\n"

# Test 4: Get Categories
echo "4. Testing Get Categories..."
curl -s "$BASE_URL/api/v1/content/categories" | python3 -m json.tool
echo -e "\n"

# Test 5: Get User Progress (if token exists)
if [ -n "$TOKEN" ]; then
    echo "5. Testing Get User Progress (authenticated)..."
    curl -s "$BASE_URL/api/v1/progress/user" \
      -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
    echo -e "\n"
else
    echo "5. Skipping authenticated tests - no token"
    echo -e "\n"
fi

# Test 6: Test Static File
echo "6. Testing Static File Access..."
curl -s -I "$BASE_URL/media/images/animals/cat.jpg" | head -5
echo -e "\n"

echo "Testing complete!"
