# 🚀 Bojang Prisma Backend Setup Guide

## ✅ What's Been Created

### 🏗️ **Complete Prisma Backend Structure**
- **Prisma Schema** - Type-safe database models with relationships
- **Node.js Express API** - RESTful API with authentication
- **Route Handlers** - Auth, Content, Progress, Sync endpoints
- **Middleware** - JWT authentication and validation
- **Font Update** - App now uses Comfortaa (Feather-style) fonts

---

## 🛠️ **Quick Setup (5 Minutes)**

### **Step 1: Install Backend Dependencies**
```bash
cd /Users/tashitsering/Desktop/bojang/backend
npm install
```

### **Step 2: Setup Environment**
```bash
# Copy environment template
cp env.example .env

# Edit .env file with your database credentials
nano .env
```

**Update your `.env` file:**
```env
DATABASE_URL="postgresql://bojang_user:your_password@localhost:5432/bojang_db?schema=public"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
PORT=3000
NODE_ENV="development"
```

### **Step 3: Setup Database with Prisma**
```bash
# Generate Prisma client
npx prisma generate

# Push schema to database (creates all tables)
npx prisma db push

# Seed database with initial data
npm run db:seed

# (Optional) Open Prisma Studio to view data
npx prisma studio
```

### **Step 4: Start Backend Server**
```bash
npm run dev
```

Your API will be running at: `http://localhost:3000` 🎉

---

## 📱 **Update Flutter App**

### **Update API Base URL**
In `/Users/tashitsering/Desktop/bojang/lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://localhost:3000/api'; // ✅ Already set
```

### **Test the Connection**
```bash
cd /Users/tashitsering/Desktop/bojang
flutter pub get
flutter run
```

---

## 🔧 **Database Management**

### **Prisma Commands**
```bash
# View database in browser
npx prisma studio

# Reset database (careful!)
npx prisma db push --force-reset

# Generate client after schema changes
npx prisma generate

# Create and run migrations
npx prisma migrate dev --name init
```

### **Seed Database with Sample Data**
The backend includes a seed script that creates:
- ✅ **Categories** (Greetings, Numbers, Colors, etc.)
- ✅ **Levels** (3 levels per category)
- ✅ **Sample Questions** (from your JSON files)
- ✅ **Achievements** (streak, accuracy, quiz milestones)
- ✅ **Games** (Memory Match configurations)

---

## 🔌 **API Endpoints**

### **Authentication**
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login user
- `POST /api/v1/auth/logout` - Logout user
- `POST /api/v1/auth/refresh` - Refresh JWT token

### **Content**
- `GET /api/v1/content/categories` - Get all categories
- `GET /api/v1/content/categories/:id/levels` - Get levels for category
- `GET /api/v1/content/levels/:id/questions` - Get questions for level
- `GET /api/v1/content/levels/:id/games` - Get games for level
- `GET /api/v1/content/version` - Get content version info
- `GET /api/v1/content/search?q=term` - Search content

### **Progress**
- `POST /api/v1/progress/quiz-session` - Submit quiz results
- `POST /api/v1/progress/game-score` - Submit game score
- `POST /api/v1/progress/streak` - Update daily streak

### **User**
- `GET /api/v1/user/profile` - Get user profile
- `GET /api/v1/user/progress` - Get user progress stats

### **Achievements & Social**
- `GET /api/v1/achievements` - Get all achievements
- `GET /api/v1/achievements/user` - Get user's unlocked achievements
- `GET /api/v1/leaderboard?type=weekly_xp` - Get leaderboards

### **Sync**
- `POST /api/v1/sync/offline-data` - Sync offline data

---

## 🧪 **Test Your API**

### **Health Check**
```bash
curl http://localhost:3000/health
```

### **Register Test User**
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@bojang.app",
    "username": "testuser",
    "password": "password123",
    "displayName": "Test User"
  }'
```

### **Login and Get Token**
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@bojang.app",
    "password": "password123"
  }'
```

### **Get Categories (with auth)**
```bash
curl http://localhost:3000/api/v1/content/categories \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE"
```

---

## 🎨 **Font Updates Applied**

### **Feather-Style Fonts**
Your Flutter app now uses **Comfortaa** font family as the closest alternative to Duolingo's custom "Feather" font:

- ✅ **Headings** use `FontWeight.w700` (Feather Bold equivalent)
- ✅ **Body text** uses `FontWeight.w400` (Feather regular equivalent)
- ✅ **Splash screen** updated with new typography
- ✅ **Theme service** configured for consistent styling

---

## 📊 **Prisma Schema Highlights**

### **Key Models**
- **User** - Authentication and profile
- **UserProgress** - XP, streaks, overall stats
- **Category/Level** - Content organization
- **Question/QuestionOption** - Quiz questions (replaces JSON)
- **Game** - Memory match and other games
- **QuizSession/QuizResult** - Detailed quiz tracking
- **Achievement/UserAchievement** - Gamification system
- **SyncQueue** - Offline data synchronization

### **Type Safety**
- ✅ **Enums** for question types, difficulties, rarities
- ✅ **Relations** properly defined with foreign keys
- ✅ **Indexes** for performance optimization
- ✅ **Constraints** for data validation

---

## 🔄 **Offline/Online Flow**

### **How It Works**
1. **Offline**: App uses existing JSON files + local storage
2. **Online**: App fetches from API + caches locally
3. **Sync**: Offline data automatically syncs when connected
4. **Fallback**: Always falls back to cached/JSON data

### **Smart Caching**
- ✅ **Content caching** with version checking
- ✅ **Offline queue** for unsent data
- ✅ **Automatic retry** logic
- ✅ **Conflict resolution** strategies

---

## 🚀 **Next Steps**

### **Immediate (Today)**
1. **Start backend**: `npm run dev`
2. **Test API**: Use curl or Postman
3. **Run Flutter app**: Should connect automatically
4. **Create test account**: Register and login

### **This Week**
1. **Migrate JSON questions** to database
2. **Test offline/online switching**
3. **Verify sync functionality**
4. **Add sample users for testing**

### **Next Week**
1. **Deploy to cloud** (Heroku, Railway, or Vercel)
2. **Set up production database**
3. **Configure environment variables**
4. **Add monitoring and logging**

---

## 🎯 **Key Benefits of Prisma**

### **Type Safety**
- ✅ **Auto-generated types** for all database models
- ✅ **Compile-time errors** prevent runtime issues
- ✅ **IntelliSense support** for better development

### **Developer Experience**
- ✅ **Prisma Studio** - Visual database browser
- ✅ **Migration system** - Version control for database
- ✅ **Query optimization** - Efficient database queries

### **Production Ready**
- ✅ **Connection pooling** - Handles high traffic
- ✅ **Query caching** - Better performance
- ✅ **Security features** - SQL injection prevention

---

## 🔧 **Troubleshooting**

### **Common Issues**

**Database Connection Error:**
```bash
# Check PostgreSQL is running
brew services list | grep postgresql

# Restart if needed
brew services restart postgresql@15
```

**Prisma Client Not Found:**
```bash
# Regenerate Prisma client
npx prisma generate
```

**Port Already in Use:**
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9
```

**Migration Issues:**
```bash
# Reset database (loses data)
npx prisma db push --force-reset
```

---

## 🎉 **You're All Set!**

Your Bojang app now has:
- ✅ **Professional Prisma backend** with type safety
- ✅ **Feather-style fonts** (Comfortaa) like Duolingo
- ✅ **Complete API** with authentication
- ✅ **Offline-first architecture** that scales
- ✅ **Production-ready database** schema

**Start the backend and watch your Tibetan learning app come to life!** 🚀

---

**Quick Start Summary:**
```bash
cd backend && npm install
cp env.example .env  # Edit database URL
npx prisma db push
npm run dev
# Backend running at http://localhost:3000 🎉
```
