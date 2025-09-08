#!/bin/bash

# Individual test runner to check each component
echo "🧪 Running individual tests to identify issues..."

echo "📊 Testing models..."
flutter test test/models/level_models_test.dart || echo "❌ level_models_test.dart FAILED"

echo "📊 Testing quiz question model..."
flutter test test/models/quiz_question_test.dart || echo "❌ quiz_question_test.dart FAILED"

echo "📱 Testing splash screen..."
flutter test test/screens/splash_screen_test.dart || echo "❌ splash_screen_test.dart FAILED"

echo "📱 Testing home page..."
flutter test test/screens/home_page_test.dart || echo "❌ home_page_test.dart FAILED"

echo "📱 Testing simple widget test..."
flutter test test/widget_test.dart || echo "❌ widget_test.dart FAILED"

echo "✅ Individual tests completed. Check output for failures."

