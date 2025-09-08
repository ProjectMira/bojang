#!/bin/bash

# iOS Build Helper Script
# Shows all available build options for Bojang Flutter App

echo "🚀 Bojang iOS Build Scripts"
echo "=========================="
echo
echo "Available build scripts:"
echo

echo "📱 TestFlight Distribution:"
echo "   ./build_testflight.sh"
echo "   → Quick build for TestFlight internal testing"
echo

echo "🏪 App Store Release (Simple):"
echo "   ./build_appstore_simple.sh"
echo "   → Quick build for App Store submission"
echo

echo "🏪 App Store Release (Full):"
echo "   ./build_appstore.sh [options]"
echo "   → Comprehensive build with validation and optimization"
echo "   Options:"
echo "     --team-id TEAM_ID        Set Apple Developer Team ID"
echo "     --bundle-id BUNDLE_ID    Set app bundle identifier"
echo "     --api-key API_KEY        App Store Connect API key"
echo "     --api-issuer ISSUER      App Store Connect API issuer"
echo "     --skip-tests             Skip running tests"
echo "     --auto-upload            Automatically upload after build"
echo

echo "⚙️  Complete Build Process:"
echo "   ./build_ios.sh [options]"
echo "   → Full featured build script with all options"
echo "   Options:"
echo "     --team-id TEAM_ID        Set Apple Developer Team ID"
echo "     --bundle-id BUNDLE_ID    Set app bundle identifier"
echo "     --clean-only             Only clean the project"
echo

echo "📋 Setup Requirements:"
echo "1. Apple Developer Account ($99/year)"
echo "2. Xcode with command line tools"
echo "3. CocoaPods installed"
echo "4. Flutter installed and in PATH"
echo "5. Bundle ID registered in Apple Developer Console"
echo

echo "🔧 Before first build:"
echo "1. Update ios/ExportOptions.plist with your Team ID"
echo "2. Update ios/ExportOptionsAppStore.plist with your Team ID"
echo "3. Configure code signing in Xcode"
echo "4. Set unique bundle identifier"
echo

echo "📖 For detailed setup instructions:"
echo "   cat iOS_BUILD_SETUP.md"
echo

echo "💡 Quick start (after setup):"
echo "   chmod +x *.sh"
echo "   ./build_testflight.sh      # For TestFlight"
echo "   ./build_appstore_simple.sh # For App Store"
echo

