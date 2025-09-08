#!/bin/bash

# Test Runner Script for Bojang - Tibetan Learning App
# This script runs tests systematically to identify and resolve issues

echo "🧪 Bojang Test Suite Runner"
echo "=========================="

# Check Flutter installation
echo "📋 Checking Flutter installation..."
flutter --version || { echo "❌ Flutter not found"; exit 1; }

# Check for test dependencies
echo "📦 Getting dependencies..."
flutter pub get || { echo "❌ Failed to get dependencies"; exit 1; }

# Run static analysis
echo "🔍 Running static analysis..."
dart analyze . || echo "⚠️  Static analysis found issues"

# Run individual test categories
echo ""
echo "🧪 Running test categories..."

# 1. Model tests (should be simplest)
echo "📊 Testing models..."
flutter test test/models/ --reporter=compact || echo "❌ Model tests failed"

# 2. Test helpers validation
echo "🛠️  Testing helpers..."
flutter test test/comprehensive_test.dart --reporter=compact || echo "❌ Helper tests failed"

# 3. Screen tests
echo "📱 Testing screens..."
flutter test test/screens/ --reporter=compact || echo "❌ Screen tests failed"

# 4. Integration tests
echo "🔗 Testing integration..."
flutter test test/integration/ --reporter=compact || echo "❌ Integration tests failed"

# 5. Cross-platform tests
echo "🌐 Testing cross-platform compatibility..."
flutter test test/cross_platform/ --reporter=compact || echo "❌ Cross-platform tests failed"

# 6. Full test suite
echo "🎯 Running full test suite..."
flutter test --reporter=compact || echo "❌ Some tests failed"

echo ""
echo "✅ Test run completed"
echo "Check output above for any failures"

