#!/bin/bash

echo "🧪 Testing Bojang API Architecture"
echo "=================================="

BASE_URL="http://localhost:3000"

echo ""
echo "1. 🏥 Health Check"
echo "-------------------"
curl -s $BASE_URL/health | jq .

echo ""
echo "2. 🖼️  Testing Image Serving"
echo "----------------------------"
echo "Status: $(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/media/images/animals/dog.jpg)"
echo "Content-Type: $(curl -s -I $BASE_URL/media/images/animals/dog.jpg | grep -i content-type)"

echo ""
echo "3. 🎵 Testing Audio Serving"
echo "----------------------------"
echo "Status: $(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/media/audio/animals/khyi_dog.wav)"
echo "Content-Length: $(curl -s -I $BASE_URL/media/audio/animals/khyi_dog.wav | grep -i content-length)"

echo ""
echo "4. 📁 Available Media Files"
echo "----------------------------"
echo "Images:"
ls backend/public/images/*/ | head -3
echo ""
echo "Audio:"
ls backend/public/audio/*/ | head -3

echo ""
echo "5. 🗃️  Database Status"
echo "---------------------"
cd backend
echo "Categories: $(echo "SELECT COUNT(*) FROM categories;" | npx prisma db execute --stdin 2>/dev/null || echo 'N/A')"
echo "Questions: $(echo "SELECT COUNT(*) FROM questions;" | npx prisma db execute --stdin 2>/dev/null || echo 'N/A')"
echo "Questions with Audio: $(echo "SELECT COUNT(*) FROM questions WHERE question_audio_url IS NOT NULL;" | npx prisma db execute --stdin 2>/dev/null || echo 'N/A')"
echo "Questions with Images: $(echo "SELECT COUNT(*) FROM questions WHERE question_image_url IS NOT NULL;" | npx prisma db execute --stdin 2>/dev/null || echo 'N/A')"

echo ""
echo "✅ API Architecture Test Complete!"
echo ""
echo "🚀 Your Tibetan learning app is now fully API-based!"
echo "📱 Update your Flutter app to consume these endpoints:"
echo "   • Categories: GET /api/v1/content/categories"
echo "   • Questions: GET /api/v1/content/levels/:id/questions"
echo "   • Media: GET /media/images/* and /media/audio/*"
echo ""
echo "📖 See API_ARCHITECTURE_GUIDE.md for detailed integration instructions."
