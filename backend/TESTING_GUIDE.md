# Backend API Testing Guide

## 🧪 Testing Your Bojang Backend API

This guide covers how to test your backend API both locally and on Render.

## 📋 Test Results Summary

### ✅ Working Endpoints (Local)

| Endpoint | Method | Status | Description |
|----------|--------|--------|-------------|
| `/health` | GET | ✅ Working | Health check |
| `/api/v1/auth/register` | POST | ✅ Working | User registration |
| `/api/v1/auth/login` | POST | ✅ Working | User login |
| `/api/v1/content/categories` | GET | ✅ Working | Get categories (auth required) |
| `/api/v1/user/progress` | GET | ✅ Working | Get user progress (auth required) |
| `/media/images/animals/cat.jpg` | GET | ✅ Working | Static file serving |

### 🔧 Testing Methods

## Method 1: Using Test Scripts

### Quick Test (cURL)
```bash
cd /Users/tashitsering/Desktop/bojang/backend
./test_with_curl.sh
```

### Comprehensive Test
```bash
./test_api.sh http://localhost:3000
```

### Test Production (Render)
```bash
./test_api.sh https://your-service.onrender.com
```

## Method 2: Manual Testing with cURL

### 1. Health Check
```bash
curl http://localhost:3000/health
```

### 2. Register User
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "testpass123",
    "displayName": "Test User"
  }'
```

### 3. Login and Get Token
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpass123"
  }'
```

### 4. Use Token for Authenticated Requests
```bash
TOKEN="your-jwt-token-here"
curl http://localhost:3000/api/v1/content/categories \
  -H "Authorization: Bearer $TOKEN"
```

## Method 3: Using HTTP Client (VS Code)

Use the `test_endpoints.http` file with the REST Client extension:

1. Install "REST Client" extension in VS Code
2. Open `test_endpoints.http`
3. Click "Send Request" above each endpoint
4. Update `@baseUrl` for production testing

## Method 4: Using Postman

### Setup Postman Collection:

1. **Create New Collection**: "Bojang API"
2. **Set Base URL Variable**: `{{baseUrl}}` = `http://localhost:3000`
3. **Add Authentication**: Bearer Token (get from login endpoint)

### Key Requests:

1. **POST** `/api/v1/auth/register`
2. **POST** `/api/v1/auth/login` 
3. **GET** `/api/v1/content/categories`
4. **GET** `/api/v1/user/progress`

## 🚀 Production Testing (Render)

### Prerequisites

1. **Fix Render Deployment** (see `RENDER_DEPLOYMENT_FIX.md`)
2. **Set Environment Variables** in Render dashboard
3. **Database Connection** working

### Test Production API

```bash
# Replace with your actual Render URL
RENDER_URL="https://your-service.onrender.com"

# Test health
curl $RENDER_URL/health

# Test full API
./test_api.sh $RENDER_URL
```

## 🔍 Database Testing

### Check Database Connection

```bash
# In backend directory
npm run db:studio
```

### Verify Data

```sql
-- Connect to your database and run:
SELECT COUNT(*) FROM "User";
SELECT COUNT(*) FROM "Category";
SELECT COUNT(*) FROM "Question";
```

## 📊 Performance Testing

### Load Testing with cURL

```bash
# Test multiple concurrent requests
for i in {1..10}; do
  curl -s http://localhost:3000/health &
done
wait
```

### Response Time Testing

```bash
# Measure response time
curl -w "@curl-format.txt" -s -o /dev/null http://localhost:3000/health
```

Create `curl-format.txt`:
```
     time_namelookup:  %{time_namelookup}s\n
        time_connect:  %{time_connect}s\n
     time_appconnect:  %{time_appconnect}s\n
    time_pretransfer:  %{time_pretransfer}s\n
       time_redirect:  %{time_redirect}s\n
  time_starttransfer:  %{time_starttransfer}s\n
                     ----------\n
          time_total:  %{time_total}s\n
```

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Required**: Most endpoints need JWT token
2. **CORS Issues**: Set proper CORS_ORIGIN in environment
3. **Database Connection**: Check DATABASE_URL
4. **Static Files**: Ensure public directory exists

### Debug Commands

```bash
# Check server logs
npm start

# Check database connection
npx prisma db push

# Generate Prisma client
npx prisma generate

# View database
npx prisma studio
```

## 📱 Flutter App Integration

### Test with Flutter App

1. **Update API Base URL** in Flutter app
2. **Test Registration/Login** flow
3. **Verify Content Loading**
4. **Check Offline Sync**

### API Endpoints for Flutter

- **Auth**: `/api/v1/auth/login`, `/api/v1/auth/register`
- **Content**: `/api/v1/content/categories`, `/api/v1/content/levels`
- **Progress**: `/api/v1/user/progress`, `/api/v1/progress/quiz-session`
- **Media**: `/media/images/*`, `/media/audio/*`

## 🎯 Next Steps

1. ✅ Local testing working
2. 🔧 Fix Render deployment configuration
3. 🔄 Test production deployment
4. 📱 Integrate with Flutter app
5. 🚀 Deploy to production

---

## Quick Reference

### Start Server Locally
```bash
cd backend
npm start
```

### Test Everything
```bash
./test_api.sh
```

### Test Production
```bash
./test_api.sh https://your-service.onrender.com
```
