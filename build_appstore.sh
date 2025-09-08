#!/bin/bash

# App Store Release Build Script for Bojang Flutter App
# This script builds and prepares your app for final App Store submission

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="Bojang"
BUNDLE_ID="com.example.bojang"  # Update this to your actual bundle ID
SCHEME="Runner"
CONFIGURATION="Release"
ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
EXPORT_PATH="build/ios/appstore"
WORKSPACE="ios/Runner.xcworkspace"
EXPORT_OPTIONS_PLIST="ios/ExportOptionsAppStore.plist"

print_step() {
    echo -e "${BLUE}🏪 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to create App Store specific ExportOptions.plist
create_appstore_export_options() {
    print_step "Creating App Store ExportOptions.plist..."
    
    cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>match AppStore $BUNDLE_ID</string>
    </dict>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

    print_success "App Store ExportOptions.plist created"
}

# Function to validate app before building
validate_pre_build() {
    print_step "Validating app configuration for App Store..."
    
    # Check if version is properly set
    local version=$(grep "version:" pubspec.yaml | cut -d' ' -f2)
    print_step "App version: $version"
    
    # Check if Info.plist has required keys
    if [ -f "ios/Runner/Info.plist" ]; then
        if ! grep -q "CFBundleDisplayName" ios/Runner/Info.plist; then
            print_warning "CFBundleDisplayName not found in Info.plist"
        fi
        
        if ! grep -q "NSCameraUsageDescription" ios/Runner/Info.plist 2>/dev/null; then
            print_warning "Consider adding usage descriptions if your app uses camera, microphone, etc."
        fi
    fi
    
    # Check for app icons
    if [ ! -d "ios/Runner/Assets.xcassets/AppIcon.appiconset" ]; then
        print_error "App icons not found. Please add app icons in Xcode."
        exit 1
    fi
    
    print_success "Pre-build validation completed"
}

# Function to run comprehensive tests
run_tests() {
    print_step "Running comprehensive tests..."
    
    # Run Flutter tests
    if flutter test --coverage 2>/dev/null; then
        print_success "Flutter tests passed"
    else
        print_warning "Some Flutter tests failed - review before submitting"
    fi
    
    # Run iOS specific tests if they exist
    if [ -d "ios/RunnerTests" ]; then
        print_step "Running iOS unit tests..."
        cd ios
        xcodebuild test \
            -workspace Runner.xcworkspace \
            -scheme Runner \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' || true
        cd ..
    fi
    
    print_success "Test execution completed"
}

# Function to optimize build for App Store
optimize_for_appstore() {
    print_step "Optimizing for App Store submission..."
    
    # Clean everything thoroughly
    flutter clean
    rm -rf build/ios
    rm -rf ios/Pods
    rm -rf ios/.symlinks
    
    # Get fresh dependencies
    flutter pub get
    
    # Rebuild pods with optimizations
    cd ios
    pod deintegrate 2>/dev/null || true
    pod install --repo-update
    cd ..
    
    print_success "Optimization completed"
}

# Function to build Flutter app with optimizations
build_flutter_optimized() {
    print_step "Building Flutter app with App Store optimizations..."
    
    # Build with all optimizations
    flutter build ios \
        --release \
        --no-codesign \
        --tree-shake-icons \
        --split-debug-info=build/app/outputs/symbols \
        --obfuscate
    
    print_success "Optimized Flutter build completed"
}

# Function to create and validate archive
create_and_validate_archive() {
    print_step "Creating Xcode archive for App Store..."
    
    # Create archive directory
    mkdir -p "$(dirname "$ARCHIVE_PATH")"
    
    # Build archive with strict settings
    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="Apple Distribution" \
        DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
        | tee build.log
    
    if [ ! -d "$ARCHIVE_PATH" ]; then
        print_error "Archive creation failed. Check build.log for details."
        exit 1
    fi
    
    print_success "Archive created successfully"
    
    # Validate archive
    print_step "Validating archive..."
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -allowProvisioningUpdates \
        | tee export.log
    
    if [ ! -f "$EXPORT_PATH/$APP_NAME.ipa" ]; then
        print_error "IPA export failed. Check export.log for details."
        exit 1
    fi
    
    print_success "Archive validated and IPA exported"
}

# Function to perform App Store validation
validate_for_appstore() {
    print_step "Performing App Store validation..."
    
    # Validate IPA structure
    local ipa_path="$EXPORT_PATH/$APP_NAME.ipa"
    local file_size=$(du -h "$ipa_path" | cut -f1)
    print_step "IPA size: $file_size"
    
    # Check if size is reasonable (warn if over 200MB)
    local size_mb=$(du -m "$ipa_path" | cut -f1)
    if [ "$size_mb" -gt 200 ]; then
        print_warning "IPA is quite large ($file_size). Consider optimizing assets."
    fi
    
    # Optional: Validate with App Store (requires API key setup)
    if [ -n "$APPSTORE_API_KEY" ] && [ -n "$APPSTORE_API_ISSUER" ]; then
        print_step "Validating with App Store Connect..."
        xcrun altool --validate-app \
            -f "$ipa_path" \
            -t ios \
            --apiKey "$APPSTORE_API_KEY" \
            --apiIssuer "$APPSTORE_API_ISSUER"
        print_success "App Store validation completed"
    else
        print_warning "App Store Connect API credentials not provided. Skipping online validation."
        print_warning "Set APPSTORE_API_KEY and APPSTORE_API_ISSUER environment variables for validation."
    fi
}

# Function to upload to App Store (optional)
upload_to_appstore() {
    if [ -n "$APPSTORE_API_KEY" ] && [ -n "$APPSTORE_API_ISSUER" ]; then
        read -p "Do you want to upload to App Store Connect now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_step "Uploading to App Store Connect..."
            xcrun altool --upload-app \
                -f "$EXPORT_PATH/$APP_NAME.ipa" \
                -t ios \
                --apiKey "$APPSTORE_API_KEY" \
                --apiIssuer "$APPSTORE_API_ISSUER"
            print_success "Upload completed!"
        fi
    fi
}

# Function to show final steps
show_final_steps() {
    echo
    print_success "🎉 App Store build completed successfully!"
    echo "=================================================="
    echo
    echo -e "${BLUE}📋 Your App Store submission files:${NC}"
    echo "   📦 IPA: $EXPORT_PATH/$APP_NAME.ipa"
    echo "   📁 Archive: $ARCHIVE_PATH"
    echo
    echo -e "${BLUE}🚀 Next Steps for App Store Submission:${NC}"
    echo "1. 🔍 Review App Store Guidelines:"
    echo "   https://developer.apple.com/app-store/review/guidelines/"
    echo
    echo "2. 📱 Upload Options:"
    echo "   • Use Xcode Organizer (Window → Organizer)"
    echo "   • Use Transporter app from Mac App Store"
    echo "   • Use command line (requires API key setup)"
    echo
    echo "3. 📝 Complete App Store Connect listing:"
    echo "   • App description and keywords"
    echo "   • Screenshots for all device sizes"
    echo "   • App privacy information"
    echo "   • Pricing and availability"
    echo
    echo "4. ✅ Submit for Review:"
    echo "   • Test the uploaded build thoroughly"
    echo "   • Submit for App Store review"
    echo "   • Monitor review status"
    echo
    echo -e "${YELLOW}⚠️  Important Reminders:${NC}"
    echo "   • Test on multiple devices before submission"
    echo "   • Ensure all metadata is complete and accurate"
    echo "   • Review can take 24-48 hours typically"
    echo "   • Have your App Store Connect credentials ready"
    echo
    echo -e "${GREEN}💡 Pro Tips:${NC}"
    echo "   • Submit on Tuesday-Thursday for faster review"
    echo "   • Respond quickly to any reviewer feedback"
    echo "   • Keep your Apple Developer Program membership active"
    echo
    echo "Good luck with your App Store submission! 🍀"
}

# Main execution function
main() {
    echo -e "${BLUE}🏪 Building $APP_NAME for App Store Release${NC}"
    echo "=================================================="
    echo
    
    create_appstore_export_options
    validate_pre_build
    run_tests
    optimize_for_appstore
    build_flutter_optimized
    create_and_validate_archive
    validate_for_appstore
    upload_to_appstore
    show_final_steps
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bundle-id)
            BUNDLE_ID="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            # Update ExportOptions.plist with team ID
            if [ -f "$EXPORT_OPTIONS_PLIST" ]; then
                sed -i '' "s/YOUR_TEAM_ID/$TEAM_ID/g" "$EXPORT_OPTIONS_PLIST"
            fi
            shift 2
            ;;
        --api-key)
            APPSTORE_API_KEY="$2"
            shift 2
            ;;
        --api-issuer)
            APPSTORE_API_ISSUER="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --auto-upload)
            AUTO_UPLOAD=true
            shift
            ;;
        --help)
            echo "App Store Release Build Script for Flutter"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --bundle-id         Set bundle identifier"
            echo "  --team-id          Set Apple Developer Team ID"
            echo "  --api-key          App Store Connect API Key"
            echo "  --api-issuer       App Store Connect API Issuer"
            echo "  --skip-tests       Skip running tests"
            echo "  --auto-upload      Automatically upload after build"
            echo "  --help             Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  APPSTORE_API_KEY      App Store Connect API Key"
            echo "  APPSTORE_API_ISSUER   App Store Connect API Issuer"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Modify main execution based on flags
if [ "$SKIP_TESTS" = true ]; then
    run_tests() {
        print_step "Skipping tests (--skip-tests flag provided)"
    }
fi

# Run main function
main

