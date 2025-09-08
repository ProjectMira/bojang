#!/bin/bash

# Simple App Store Release Build Script
# Quick and easy build for App Store submission

set -e

echo "🏪 Building Bojang for App Store Release..."

# Clean and prepare
echo "🧹 Cleaning project..."
flutter clean
flutter pub get

echo "📱 Installing iOS dependencies..."
cd ios && pod install && cd ..

echo "🔨 Building optimized Flutter app..."
flutter build ios --release --tree-shake-icons

echo "📦 Creating App Store archive..."
cd ios
xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath ../build/ios/Runner.xcarchive \
    archive

echo "📤 Exporting IPA for App Store..."
xcodebuild \
    -exportArchive \
    -archivePath ../build/ios/Runner.xcarchive \
    -exportPath ../build/ios/appstore \
    -exportOptionsPlist ExportOptionsAppStore.plist

cd ..

echo "✅ App Store build complete!"
echo ""
echo "📦 Your files are ready:"
echo "   IPA: build/ios/appstore/Bojang.ipa"
echo "   Archive: build/ios/Runner.xcarchive"
echo ""
echo "🚀 Next steps:"
echo "1. Open Xcode → Window → Organizer"
echo "2. Select your archive"
echo "3. Click 'Distribute App' → 'App Store Connect'"
echo "4. Complete your App Store Connect listing"
echo "5. Submit for App Store review"
echo ""
echo "Good luck with your submission! 🍀"

