# API-Based Architecture Guide

This document explains how the Bojang Tibetan Learning App now serves all content through the backend API instead of bundling assets in the mobile app.

## 🏗️ **Architecture Overview**

```
Flutter App ←→ Backend API ←→ PostgreSQL Database
                    ↓
                Media Files (Images/Audio)
```

### **Key Changes Made:**
- ✅ All media assets moved to backend (`backend/public/`)
- ✅ Static file serving configured at `/media` endpoint
- ✅ Database updated with relative paths for API serving
- ✅ Questions API enhanced to return full media URLs
- ✅ Original app assets removed (no longer bundled)

## 📡 **API Endpoints**

### **Core Content Endpoints**

#### 1. **Health Check**
```
GET /health
```
Returns server status and basic info.

#### 2. **Categories**
```
GET /api/v1/content/categories
Headers: Authorization: Bearer <token>
```
Returns all learning categories with their levels.

#### 3. **Levels Structure**
```
GET /api/v1/content/levels
Headers: Authorization: Bearer <token>
```
Returns the complete level structure (replaces `levels.json`).

#### 4. **Questions for a Level**
```
GET /api/v1/content/levels/:levelId/questions?limit=10&shuffle=true
Headers: Authorization: Bearer <token>
```
Returns questions with **full API URLs** for media files.

**Example Response:**
```json
{
  "questions": [
    {
      "id": "question_123",
      "questionType": "AUDIO_TO_TEXT",
      "questionText": "Listen to the Tibetan word. What animal is this?",
      "questionAudioUrl": "http://localhost:3000/media/audio/animals/khyi_dog.wav",
      "correctAnswer": "Dog",
      "options": [
        {
          "id": "option_1",
          "optionText": "Dog",
          "optionTextTibetan": "ཁྱི",
          "isCorrect": true
        }
      ]
    }
  ]
}
```

#### 5. **Games for a Level**
```
GET /api/v1/content/levels/:levelId/games
Headers: Authorization: Bearer <token>
```
Returns available games for the level.

### **Media Serving Endpoints**

#### **Images**
```
GET /media/images/{category}/{filename}
```
Examples:
- `/media/images/animals/dog.jpg`
- `/media/images/body-parts/eye.jpg`
- `/media/images/food/momo.jpg`

#### **Audio**
```
GET /media/audio/{category}/{filename}
```
Examples:
- `/media/audio/animals/khyi_dog.wav`
- `/media/audio/greetings/tashi-delek.wav`
- `/media/audio/phrases/butter-tea-request.wav`

## 🗂️ **Backend File Structure**

```
backend/
├── src/
│   ├── index.js              # Main server with static file serving
│   ├── routes/content.js     # Enhanced content API routes
│   └── seed.js               # Updated with API-compatible paths
├── public/                   # Media files served at /media
│   ├── images/
│   │   ├── animals/          # Animal images
│   │   ├── body-parts/       # Body part images
│   │   └── food/             # Food images
│   └── audio/
│       ├── animals/          # Animal pronunciation
│       ├── greetings/        # Common greetings
│       ├── food/             # Food vocabulary
│       └── phrases/          # Common phrases
└── prisma/schema.prisma      # Updated with multimedia support
```

## 🔄 **Question Types & Media Integration**

### **Supported Question Types:**
1. **MULTIPLE_CHOICE** - Traditional text-based questions
2. **AUDIO_TO_TEXT** - Listen to audio, choose text answer
3. **TEXT_TO_AUDIO** - Read text, choose correct audio
4. **IMAGE_TO_TEXT** - Look at image, choose text answer
5. **TEXT_TO_IMAGE** - Read text, choose matching image
6. **AUDIO_MULTIPLE_CHOICE** - Audio question with text options
7. **IMAGE_MULTIPLE_CHOICE** - Image question with text options

### **Media URL Transformation**
The API automatically converts stored relative paths to full URLs:
- **Stored**: `"images/animals/dog.jpg"`
- **Returned**: `"http://localhost:3000/media/images/animals/dog.jpg"`

## 📱 **Flutter App Integration**

### **Required Changes in Flutter App:**

#### 1. **Remove Local Assets**
- Delete `assets/audio/` and `assets/images/` directories
- Update `pubspec.yaml` to remove asset references
- Remove any local asset loading code

#### 2. **API Integration**
```dart
// Example API service
class QuizApiService {
  static const String baseUrl = 'http://localhost:3000/api/v1';
  
  Future<List<Question>> getQuestions(String levelId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/content/levels/$levelId/questions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    // Questions now include full media URLs
    return parseQuestions(response.body);
  }
}
```

#### 3. **Media Loading**
```dart
// For images
Image.network(question.questionImageUrl)

// For audio
AudioPlayer().play(UrlSource(question.questionAudioUrl))
```

#### 4. **Caching Strategy**
```dart
// Implement caching for offline support
CachedNetworkImage(
  imageUrl: question.questionImageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

## 🚀 **Deployment Considerations**

### **Development**
- Backend runs on `http://localhost:3000`
- Media served at `/media` endpoint
- CORS configured for Flutter web/mobile development

### **Production**
- Replace localhost URLs with production domain
- Configure CDN for media files (optional)
- Set up proper SSL certificates
- Implement media compression/optimization

### **Environment Configuration**
```javascript
// In production, media URLs will be:
const baseUrl = process.env.NODE_ENV === 'production' 
  ? 'https://api.bojang.com' 
  : 'http://localhost:3000';
```

## 🔒 **Security & Performance**

### **Security**
- All content endpoints require authentication
- Media files are publicly accessible (no auth needed)
- CORS properly configured
- Helmet security headers enabled

### **Performance**
- Static files served with proper caching headers
- Media files can be cached by browsers/CDN
- Supports range requests for large media files
- Gzip compression enabled

### **Offline Support**
- App should cache downloaded media locally
- Implement proper cache invalidation
- Store question data locally after download
- Sync progress when online

## 🧪 **Testing**

### **Test Media Serving**
```bash
# Test image serving
curl -I http://localhost:3000/media/images/animals/dog.jpg

# Test audio serving  
curl -I http://localhost:3000/media/audio/animals/khyi_dog.wav

# Test API endpoints
curl -H "Authorization: Bearer <token>" \
     http://localhost:3000/api/v1/content/categories
```

### **Test Question API**
```bash
# Get questions with media URLs
curl -H "Authorization: Bearer <token>" \
     "http://localhost:3000/api/v1/content/levels/LEVEL_ID/questions?limit=5"
```

## 📊 **Benefits of This Architecture**

1. **Smaller App Size** - No media assets bundled in app
2. **Dynamic Content** - Easy to update questions/media without app updates
3. **Better Performance** - Media loaded on-demand with caching
4. **Scalability** - Can serve multiple app versions from same backend
5. **Analytics** - Track which content is accessed most
6. **A/B Testing** - Easy to test different question variations
7. **Localization** - Easy to serve different language content

## 🔄 **Migration Checklist**

- [x] Move all media assets to backend/public/
- [x] Configure static file serving at /media endpoint
- [x] Update database with relative media paths
- [x] Enhance content API to return full URLs
- [x] Remove media assets from Flutter app directory
- [x] Test media serving endpoints
- [ ] Update Flutter app to use API instead of local assets
- [ ] Implement proper error handling for network requests
- [ ] Add offline caching strategy
- [ ] Test on different network conditions
- [ ] Update deployment scripts

Your Tibetan learning app now has a modern, scalable API-based architecture! 🎉
