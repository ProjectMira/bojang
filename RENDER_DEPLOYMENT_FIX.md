# Render Deployment Fix Guide

## Current Issue
Your Render service is looking for `/opt/render/project/src/backend` but your backend is located at `/opt/render/project/backend/src/`.

## Fix Steps

### 1. Update Render Service Configuration

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Select your backend service
3. Go to **Settings** → **Build & Deploy**
4. Update the following settings:
   - **Root Directory**: `backend`
   - **Build Command**: `npm install && npx prisma generate`
   - **Start Command**: `npm start`

### 2. Environment Variables

Add these environment variables in your Render service:

```env
# Database (Get this from your Render PostgreSQL service)
DATABASE_URL=postgresql://username:password@hostname:port/database

# JWT (Generate a secure secret)
JWT_SECRET=your-production-jwt-secret-key
JWT_EXPIRES_IN=7d

# Server
PORT=10000
NODE_ENV=production

# CORS (Update with your Flutter app domains)
CORS_ORIGIN=*

# Rate limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# App settings
APP_NAME=Bojang API
APP_VERSION=1.0.0
```

### 3. PostgreSQL Connection

#### Get Your Database Connection String:
1. Go to your PostgreSQL service in Render
2. Copy the **External Database URL**
3. Use this as your `DATABASE_URL` environment variable

#### For DBeaver Connection:
From your PostgreSQL service in Render, get:
- **Hostname**: (from the connection string)
- **Port**: Usually 5432
- **Database**: Your database name
- **Username**: Your database username
- **Password**: Your database password

#### DBeaver Connection Steps:
1. Open DBeaver
2. New Database Connection → PostgreSQL
3. Enter the connection details from Render
4. Test Connection
5. **Important**: Make sure your IP is whitelisted in Render (if applicable)

### 4. Deploy Steps

1. After updating the Root Directory setting, trigger a new deployment
2. Check the deployment logs for any errors
3. Test the `/health` endpoint: `https://your-service.onrender.com/health`

### 5. Common Issues

- **IP Whitelisting**: Some Render PostgreSQL services require IP whitelisting
- **SSL Mode**: You might need to add `?sslmode=require` to your DATABASE_URL
- **Connection Limits**: Free tier has connection limits

### 6. Testing the Fix

Once deployed, test these endpoints:
- `GET /health` - Should return service status
- `GET /api/v1/content/categories` - Should return categories (if seeded)

## Next Steps After Fix

1. Run database migrations: `npx prisma db push`
2. Seed your database: `npm run db:seed`
3. Test all API endpoints
