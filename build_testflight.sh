#!/bin/bash

# TestFlight Build Script for Bojang Flutter App
# This script builds and prepares your app for TestFlight distribution

set -e

echo "🚀 Building Bojang for TestFlight..."

# Clean and prepare
echo "🧹 Cleaning project..."
flutter clean
flutter pub get

echo "📱 Installing iOS dependencies..."
cd ios && pod install && cd ..

echo "🔨 Building Flutter app for iOS..."
flutter build ios --release

echo "📦 Creating Xcode archive..."
cd ios
xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath ../build/ios/Runner.xcarchive \
    archive

echo "📤 Exporting IPA for TestFlight..."
xcodebuild \
    -exportArchive \
    -archivePath ../build/ios/Runner.xcarchive \
    -exportPath ../build/ios/ipa \
    -exportOptionsPlist ExportOptions.plist

cd ..

echo "✅ Build complete! Your IPA is ready at: build/ios/ipa/Bojang.ipa"
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode and go to Window > Organizer"
echo "2. Select your archive and click 'Distribute App'"
echo "3. Choose 'App Store Connect' for TestFlight"
echo "4. Follow the prompts to upload to TestFlight"

