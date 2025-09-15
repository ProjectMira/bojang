#!/bin/bash

# Backend API Testing Script
# Usage: ./test_api.sh [BASE_URL]
# Example: ./test_api.sh http://localhost:3000
# Example: ./test_api.sh https://your-service.onrender.com

BASE_URL=${1:-"http://localhost:3000"}

echo "🧪 Testing Bojang Backend API"
echo "📡 Base URL: $BASE_URL"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local description=$3
    local data=$4
    
    echo -e "\n${BLUE}Testing: $description${NC}"
    echo -e "${YELLOW}$method $endpoint${NC}"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X $method \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X $method \
            -H "Content-Type: application/json" \
            "$BASE_URL$endpoint")
    fi
    
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    response_body=$(echo "$response" | sed '/HTTP_STATUS:/d')
    
    if [ "$http_status" -ge 200 ] && [ "$http_status" -lt 300 ]; then
        echo -e "${GREEN}✅ SUCCESS (Status: $http_status)${NC}"
        echo "$response_body" | python3 -m json.tool 2>/dev/null || echo "$response_body"
    else
        echo -e "${RED}❌ FAILED (Status: $http_status)${NC}"
        echo "$response_body"
    fi
}

echo -e "\n🏥 HEALTH CHECK"
test_endpoint "GET" "/health" "Health Check"

echo -e "\n👤 AUTHENTICATION ENDPOINTS"
test_endpoint "POST" "/api/v1/auth/register" "User Registration" '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "testpass123",
    "displayName": "Test User"
}'

test_endpoint "POST" "/api/v1/auth/login" "User Login" '{
    "email": "test@example.com",
    "password": "testpass123"
}'

echo -e "\n📚 CONTENT ENDPOINTS"
test_endpoint "GET" "/api/v1/content/categories" "Get Categories"
test_endpoint "GET" "/api/v1/content/levels" "Get Levels"

echo -e "\n📊 PROGRESS ENDPOINTS (requires auth)"
test_endpoint "GET" "/api/v1/progress/user" "Get User Progress"

echo -e "\n🏆 ACHIEVEMENT ENDPOINTS"
test_endpoint "GET" "/api/v1/achievements" "Get Achievements"

echo -e "\n🎯 LEADERBOARD ENDPOINTS"
test_endpoint "GET" "/api/v1/leaderboard/weekly" "Get Weekly Leaderboard"

echo -e "\n📱 STATIC FILES"
test_endpoint "GET" "/media/images/animals/cat.jpg" "Test Image Serving"
test_endpoint "GET" "/media/audio/animals/khyi_dog.wav" "Test Audio Serving"

echo -e "\n================================="
echo -e "🏁 ${GREEN}API Testing Complete!${NC}"
