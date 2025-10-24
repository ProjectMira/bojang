# Render Deployment Guide for Bojang Backend

## Prerequisites
1. PostgreSQL database deployed on Render
2. Environment variables configured in Render dashboard

## Environment Variables to Set in Render
```
DATABASE_URL=your_postgresql_connection_string_from_render
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
NODE_ENV=production
PORT=10000
CORS_ORIGIN=*
```

## Build Command
```
npm install
```

## Start Command
```
npm start
```

## Important Notes

### Prisma Configuration
- The `schema.prisma` file now includes `binaryTargets = ["native", "debian-openssl-3.0.x"]`
- The `postinstall` script automatically runs `prisma generate` after npm install
- This ensures the correct Prisma client binaries are available for Render's Linux environment

### Database Migration
If you need to run migrations on first deployment:
1. Add a one-time build command: `npm install && npx prisma db push`
2. After successful deployment, change back to: `npm install`

### Troubleshooting
- If you get Prisma binary errors, ensure the `binaryTargets` in schema.prisma includes `debian-openssl-3.0.x`
- Check that DATABASE_URL is correctly set with the Render PostgreSQL connection string
- Verify all environment variables are set in the Render dashboard

## Health Check
Once deployed, test the API at: `https://your-app-name.onrender.com/health`
