#!/bin/bash

# TestFlight Build & Upload Script for Bojang (Flutter iOS)
# - Builds the iOS app
# - Exports an IPA suitable for TestFlight
# - Optionally uploads to App Store Connect (TestFlight) if API creds provided

set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() { echo -e "${BLUE}📱 $1${NC}"; }
print_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_err()  { echo -e "${RED}❌ $1${NC}"; }

# Options (env or flags)
API_KEY="${APPSTORE_API_KEY:-}"
API_ISSUER="${APPSTORE_API_ISSUER:-}"
TEAM_ID="${APPLE_TEAM_ID:-}"
SKIP_CLEAN=false
NO_UPLOAD=false

usage() {
  echo "TestFlight Build & Upload Script"
  echo
  echo "Usage: $0 [--team-id TEAMID] [--api-key KEY --api-issuer ISSUER] [--skip-clean] [--no-upload]"
  echo
  echo "Environment variables:"
  echo "  APPLE_TEAM_ID         Apple Developer Team ID (optional)"
  echo "  APPSTORE_API_KEY      App Store Connect API Key (optional)"
  echo "  APPSTORE_API_ISSUER   App Store Connect API Issuer (optional)"
  echo
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      TEAM_ID="$2"; shift 2 ;;
    --api-key)
      API_KEY="$2"; shift 2 ;;
    --api-issuer)
      API_ISSUER="$2"; shift 2 ;;
    --skip-clean)
      SKIP_CLEAN=true; shift ;;
    --no-upload)
      NO_UPLOAD=true; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      print_err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Pre-flight checks
print_step "Checking tools..."
command -v flutter >/dev/null || { print_err "Flutter not found in PATH"; exit 1; }
command -v xcodebuild >/dev/null || { print_err "xcodebuild not found (install Xcode + CLT)"; exit 1; }
command -v pod >/dev/null || { print_err "CocoaPods not found. Install with: sudo gem install cocoapods"; exit 1; }
print_ok "All required tools available"

echo -e "${BLUE}🚀 Building Bojang for TestFlight...${NC}"

# Clean & deps
if [ "$SKIP_CLEAN" = false ]; then
  print_step "Cleaning project..."
  flutter clean
fi

print_step "Fetching Flutter packages..."
flutter pub get

print_step "Installing iOS pods..."
(
  cd ios
  pod install --repo-update
)

# Build
print_step "Building Flutter iOS (release)..."
flutter build ios --release --no-codesign

# Archive
print_step "Creating Xcode archive..."
(
  cd ios
  if [ -n "$TEAM_ID" ]; then
    xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath ../build/ios/Runner.xcarchive \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    archive | grep -E "(warning|error|succeeded|failed)" || true
  else
    xcodebuild \
    -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath ../build/ios/Runner.xcarchive \
    -allowProvisioningUpdates \
    archive | grep -E "(warning|error|succeeded|failed)" || true
  fi
)

# Export IPA (uses ios/ExportOptions.plist, or temp one if TEAM_ID provided)
print_step "Exporting IPA for TestFlight..."
(
  cd ios
  EXPORT_PLIST="ExportOptions.plist"
  TMP_EXPORT_PLIST=""
  if [ -n "$TEAM_ID" ]; then
    TMP_EXPORT_PLIST="../build/ios/tmp_ExportOptions_TestFlight.plist"
    mkdir -p ../build/ios
    cat > "$TMP_EXPORT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
EOF
    EXPORT_PLIST="$TMP_EXPORT_PLIST"
  fi

  xcodebuild \
    -exportArchive \
    -archivePath ../build/ios/Runner.xcarchive \
    -exportPath ../build/ios/ipa \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates | grep -E "(warning|error|succeeded|failed)" || true
)

# Locate IPA
IPA_PATH="$(ls -1 build/ios/ipa/*.ipa 2>/dev/null | head -n 1 || true)"
if [ -z "$IPA_PATH" ]; then
  print_err "No IPA found in build/ios/ipa. Check export step."
  exit 1
fi

FILE_SIZE="$(du -h "$IPA_PATH" | cut -f1)"
print_ok "IPA created: $IPA_PATH ($FILE_SIZE)"

# Upload (optional)
if [ "$NO_UPLOAD" = true ]; then
  print_warn "Skipping upload (--no-upload provided)"
else
  if [ -n "$API_KEY" ] && [ -n "$API_ISSUER" ]; then
    print_step "Uploading to App Store Connect (TestFlight)..."
    # altool is deprecated in favor of Transporter GUI, but still works for uploads with API key
    if xcrun altool --upload-app -f "$IPA_PATH" -t ios --apiKey "$API_KEY" --apiIssuer "$API_ISSUER"; then
      print_ok "Upload initiated successfully. Check App Store Connect/TestFlight."
    else
      print_warn "Upload failed via API. You can upload manually using Xcode Organizer or Transporter."
    fi
  else
    print_warn "API credentials not provided. Skipping auto-upload."
  fi
fi

echo
print_ok "Build complete!"
echo
echo -e "${BLUE}📦 Artifacts:${NC}"
echo "  • IPA: $IPA_PATH"
echo "  • Archive: build/ios/Runner.xcarchive"
echo
echo -e "${BLUE}🚀 Upload options:${NC}"
echo "  • Automatic (provided): API Key/Issuer"
echo "  • Manual: Xcode → Window → Organizer → Archives → Distribute App → App Store Connect"
echo "  • Transporter app (recommended by Apple)"
echo
echo -e "${YELLOW}ℹ️  Tips:${NC}"
echo "  • Ensure ios/ExportOptions.plist has method=app-store"
echo "  • Increment version in pubspec.yaml for each new build"
echo


