#!/bin/bash

# iOS Build Script for TestFlight and App Store Distribution
# This script builds the Flutter app for iOS release and prepares it for TestFlight/App Store

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Bojang"
BUNDLE_ID="com.example.bojang"  # Update this to your actual bundle ID
SCHEME="Runner"
CONFIGURATION="Release"
ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
EXPORT_PATH="build/ios/ipa"
WORKSPACE="ios/Runner.xcworkspace"

# Xcode Export Options
EXPORT_OPTIONS_PLIST="ios/ExportOptions.plist"

print_step() {
    echo -e "${BLUE}📱 $1${NC}"
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

# Function to check if required tools are installed
check_requirements() {
    print_step "Checking requirements..."
    
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed or command line tools are not set up"
        exit 1
    fi
    
    if ! command -v pod &> /dev/null; then
        print_error "CocoaPods is not installed. Install with: sudo gem install cocoapods"
        exit 1
    fi
    
    print_success "All requirements met"
}

# Function to create ExportOptions.plist if it doesn't exist
create_export_options() {
    if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
        print_step "Creating ExportOptions.plist..."
        
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
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>match AppStore $BUNDLE_ID</string>
    </dict>
</dict>
</plist>
EOF
        
        print_warning "Created ExportOptions.plist - Please update YOUR_TEAM_ID with your Apple Developer Team ID"
        print_warning "Also update the bundle ID if needed: $BUNDLE_ID"
    fi
}

# Function to clean the project
clean_project() {
    print_step "Cleaning project..."
    
    # Flutter clean
    flutter clean
    
    # Clean iOS build folder
    rm -rf build/ios
    
    # Clean Xcode derived data (optional)
    # rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
    
    print_success "Project cleaned"
}

# Function to get dependencies
get_dependencies() {
    print_step "Getting Flutter dependencies..."
    flutter pub get
    
    print_step "Installing iOS pods..."
    cd ios
    pod install --repo-update
    cd ..
    
    print_success "Dependencies installed"
}

# Function to build Flutter app
build_flutter() {
    print_step "Building Flutter app for iOS release..."
    
    # Build for iOS release
    flutter build ios --release --no-codesign
    
    print_success "Flutter build completed"
}

# Function to create Xcode archive
create_archive() {
    print_step "Creating Xcode archive..."
    
    # Create archive directory
    mkdir -p "$(dirname "$ARCHIVE_PATH")"
    
    # Build archive
    xcodebuild archive \
        -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -archivePath "$ARCHIVE_PATH" \
        -allowProvisioningUpdates \
        CODE_SIGN_IDENTITY="Apple Distribution" \
        | grep -E "(warning|error|note|succeeded|failed)" || true
    
    if [ ! -d "$ARCHIVE_PATH" ]; then
        print_error "Archive creation failed"
        exit 1
    fi
    
    print_success "Archive created successfully"
}

# Function to export IPA
export_ipa() {
    print_step "Exporting IPA for App Store distribution..."
    
    # Create export directory
    mkdir -p "$EXPORT_PATH"
    
    # Export archive
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -allowProvisioningUpdates \
        | grep -E "(warning|error|note|succeeded|failed)" || true
    
    if [ ! -f "$EXPORT_PATH/$APP_NAME.ipa" ]; then
        print_error "IPA export failed"
        print_warning "Check the export options and provisioning profiles"
        exit 1
    fi
    
    print_success "IPA exported successfully"
}

# Function to validate the build
validate_build() {
    print_step "Validating build..."
    
    if [ -f "$EXPORT_PATH/$APP_NAME.ipa" ]; then
        local file_size=$(du -h "$EXPORT_PATH/$APP_NAME.ipa" | cut -f1)
        print_success "IPA file created: $EXPORT_PATH/$APP_NAME.ipa (Size: $file_size)"
        
        # Optional: Validate with App Store
        print_step "Validating with App Store (optional)..."
        xcrun altool --validate-app \
            -f "$EXPORT_PATH/$APP_NAME.ipa" \
            -t ios \
            --apiKey "YOUR_API_KEY" \
            --apiIssuer "YOUR_API_ISSUER" || true
        
        print_warning "Note: API key validation requires App Store Connect API key setup"
    else
        print_error "IPA file not found"
        exit 1
    fi
}

# Function to show next steps
show_next_steps() {
    echo
    print_success "Build completed successfully! 🎉"
    echo
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. 📱 Upload to TestFlight:"
    echo "   - Use Xcode -> Window -> Organizer -> Archives"
    echo "   - Or use: xcrun altool --upload-app -f $EXPORT_PATH/$APP_NAME.ipa -t ios --apiKey YOUR_API_KEY --apiIssuer YOUR_API_ISSUER"
    echo
    echo "2. 🔧 Before uploading, ensure:"
    echo "   - Update ExportOptions.plist with correct Team ID"
    echo "   - Update bundle ID if different from: $BUNDLE_ID"
    echo "   - Provisioning profiles are set up in Apple Developer Console"
    echo "   - App Store Connect record exists for your app"
    echo
    echo "3. 📦 Files created:"
    echo "   - Archive: $ARCHIVE_PATH"
    echo "   - IPA: $EXPORT_PATH/$APP_NAME.ipa"
    echo
    echo -e "${YELLOW}⚠️  Important:${NC}"
    echo "   - Increment version number in pubspec.yaml for each new build"
    echo "   - Test thoroughly before submitting to App Store Review"
    echo "   - Review App Store guidelines before submission"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting iOS build for $APP_NAME${NC}"
    echo "=================================================="
    
    check_requirements
    create_export_options
    clean_project
    get_dependencies
    build_flutter
    create_archive
    export_ipa
    validate_build
    show_next_steps
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
        --clean-only)
            clean_project
            exit 0
            ;;
        --help)
            echo "iOS Build Script for Flutter"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --bundle-id     Set bundle identifier (default: com.example.bojang)"
            echo "  --team-id       Set Apple Developer Team ID"
            echo "  --clean-only    Only clean the project"
            echo "  --help          Show this help message"
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

# Run main function
main

