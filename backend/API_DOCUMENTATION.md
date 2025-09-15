# Bojang API Documentation

## Overview
The Bojang API provides comprehensive backend services for the Tibetan language learning application. This RESTful API handles user authentication, content management, progress tracking, and more.

## Swagger Documentation
Interactive API documentation is available via Swagger UI:

### Local Development
- **URL**: http://localhost:3000/api/docs
- **Access**: Available when running the development server

### Production
- **URL**: https://bojang.onrender.com/api/docs
- **Access**: Available on the deployed Render service

## API Endpoints Overview

### Authentication (`/api/v1/auth`)
- `POST /register` - Register a new user account
- `POST /login` - User login with email/password
- `POST /google` - Google OAuth authentication
- `POST /logout` - User logout
- `POST /refresh` - Refresh JWT token

### Content (`/api/v1/content`)
- `GET /categories` - Get all learning categories
- `GET /categories/{categoryId}/levels` - Get levels for a category
- `GET /levels/{levelId}/questions` - Get questions for a level
- `GET /levels/{levelId}/games` - Get games for a level

### User Management (`/api/v1/user`)
- `GET /profile` - Get user profile
- `PUT /profile` - Update user profile
- `GET /progress` - Get user learning progress
- `GET /achievements` - Get user achievements

### Progress Tracking (`/api/v1/progress`)
- `POST /quiz-session` - Submit quiz session results
- `POST /game-score` - Submit game score
- `PUT /streak` - Update daily streak

### Achievements (`/api/v1/achievements`)
- `GET /` - Get all available achievements
- `GET /user` - Get user's unlocked achievements

### Leaderboard (`/api/v1/leaderboard`)
- `GET /` - Get leaderboard rankings
- Query parameters: `type`, `period`, `limit`

### Sync (`/api/v1/sync`)
- `POST /offline-data` - Sync offline data
- `GET /content/version` - Get content version info

## Authentication
The API uses JWT (JSON Web Tokens) for authentication. Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### Getting a Token
1. **Register**: `POST /api/v1/auth/register`
2. **Login**: `POST /api/v1/auth/login`
3. **Google Auth**: `POST /api/v1/auth/google`

## Data Models

### User
- `id`: Unique identifier
- `email`: User email address
- `username`: Unique username
- `displayName`: Display name
- `profileImageUrl`: Profile image URL
- `createdAt`: Account creation timestamp
- `lastLogin`: Last login timestamp
- `isActive`: Account status

### Category
- `id`: Unique identifier
- `name`: Category name
- `tibetanName`: Tibetan name
- `description`: Category description
- `iconUrl`: Icon URL
- `sortOrder`: Display order

### Level
- `id`: Unique identifier
- `categoryId`: Parent category
- `levelNumber`: Level number
- `name`: Level name
- `difficulty`: BEGINNER | INTERMEDIATE | ADVANCED
- `unlockRequirement`: XP required to unlock

### Question
- `id`: Unique identifier
- `levelId`: Parent level
- `questionType`: Type of question (MULTIPLE_CHOICE, etc.)
- `questionText`: Question text in English
- `questionTextTibetan`: Question text in Tibetan
- `correctAnswer`: Correct answer
- `options`: Array of answer options

## Error Responses
All endpoints return consistent error responses:

```json
{
  "error": "Error message",
  "details": "Additional error details"
}
```

### HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (authentication required)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `409` - Conflict (duplicate resource)
- `500` - Internal Server Error

## Rate Limiting
- **Window**: 15 minutes
- **Limit**: 100 requests per IP
- **Applies to**: All `/api/` endpoints

## CORS
- **Development**: `http://localhost:*`
- **Production**: Configured for Flutter app domains

## Development

### Running Locally
```bash
npm install
npm run dev
```

### Environment Variables
```env
DATABASE_URL=postgresql://...
JWT_SECRET=your-secret-key
NODE_ENV=development
PORT=3000
```

### Testing API
Use the Swagger UI interface for interactive testing, or use tools like:
- Postman
- cURL
- Thunder Client (VS Code)

## Production Deployment
The API is deployed on Render with:
- Automatic deployments from GitHub
- PostgreSQL database
- Environment variables configured
- Swagger documentation available

## Support
For API support or questions:
- Check the Swagger documentation first
- Review error messages and status codes
- Contact the development team

## Version History
- **v1.0.0** - Initial API release with full authentication and content management
