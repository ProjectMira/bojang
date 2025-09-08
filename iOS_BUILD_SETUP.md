# iOS Build Setup Guide for Bojang

This guide will help you set up and build your Flutter app for TestFlight and App Store distribution.

## 🛠️ Prerequisites

1. **Xcode** - Latest version from Mac App Store
2. **Flutter** - Ensure it's properly installed and in your PATH
3. **CocoaPods** - Install with: `sudo gem install cocoapods`
4. **Apple Developer Account** - Required for app distribution

## 📝 Configuration Steps

### 1. Apple Developer Setup
- Enroll in Apple Developer Program ($99/year)
- Create your app identifier in Apple Developer Console
- Set up provisioning profiles and certificates

### 2. Update Bundle Identifier
1. Open `ios/Runner.xcodeproj` in Xcode
2. Select Runner target → Signing & Capabilities
3. Update Bundle Identifier to your unique identifier (e.g., `com.yourcompany.bojang`)
4. Update the same identifier in `ios/ExportOptions.plist`

### 3. Update Team ID
1. Find your Team ID in Apple Developer Console
2. Open `ios/ExportOptions.plist`
3. Replace `YOUR_TEAM_ID` with your actual Team ID

### 4. Configure Code Signing
1. Open `ios/Runner.xcodeproj` in Xcode
2. Select Runner target → Signing & Capabilities
3. Choose "Automatically manage signing"
4. Select your development team

## 🚀 Building Your App

### For TestFlight Distribution:

```bash
# Make script executable
chmod +x build_testflight.sh

# Run the build
./build_testflight.sh
```

### For App Store Release:

```bash
# Simple App Store build
chmod +x build_appstore_simple.sh
./build_appstore_simple.sh

# OR comprehensive App Store build with validation
chmod +x build_appstore.sh
./build_appstore.sh --team-id "YOUR_TEAM_ID" --bundle-id "com.yourcompany.bojang"
```

### For Complete Build Process (Advanced):

```bash
# Make script executable
chmod +x build_ios.sh

# Run with your team ID
./build_ios.sh --team-id "YOUR_TEAM_ID" --bundle-id "com.yourcompany.bojang"
```

## 📤 Uploading to TestFlight

After building, you have two options:

### Option 1: Using Xcode Organizer
1. Open Xcode
2. Go to Window → Organizer
3. Select your archive
4. Click "Distribute App"
5. Choose "App Store Connect"
6. Follow the upload process

### Option 2: Using Command Line (Advanced)
```bash
xcrun altool --upload-app \
    -f build/ios/ipa/Bojang.ipa \
    -t ios \
    --apiKey YOUR_API_KEY \
    --apiIssuer YOUR_API_ISSUER
```

## 🔍 Troubleshooting

### Common Issues:

1. **Code signing errors**
   - Ensure your Apple Developer account is active
   - Check that certificates are valid
   - Verify provisioning profiles

2. **Build failures**
   - Clean project: `flutter clean`
   - Update dependencies: `flutter pub get && cd ios && pod install`
   - Check Xcode for specific errors

3. **Archive not found**
   - Ensure you're building in Release mode
   - Check that all dependencies are properly resolved

## 📋 Pre-Release Checklist

- [ ] App icon is set (1024x1024 for App Store)
- [ ] Bundle identifier is unique and registered
- [ ] Version number is incremented in `pubspec.yaml`
- [ ] All required permissions are declared in Info.plist
- [ ] App has been tested on real devices
- [ ] Screenshots prepared for App Store listing
- [ ] App description and metadata ready

## 📤 App Store Release Process

### Using Simple App Store Script:
```bash
./build_appstore_simple.sh
```

### Using Comprehensive App Store Script:
```bash
# With full validation and optimization
./build_appstore.sh --team-id "YOUR_TEAM_ID" --bundle-id "com.yourcompany.bojang"

# With API credentials for automatic upload
export APPSTORE_API_KEY="your_api_key"
export APPSTORE_API_ISSUER="your_api_issuer"
./build_appstore.sh --auto-upload
```

## 🏪 App Store Submission Process

1. **Upload to TestFlight** (Internal Testing)
2. **External TestFlight Testing** (Optional)
3. **Create App Store Listing** in App Store Connect
4. **Submit for App Store Review**
5. **Release** once approved

### App Store Connect Setup Required:
- App privacy questionnaire
- App description and keywords  
- Screenshots for all supported devices
- Pricing and availability settings
- Age rating information

## 📞 Support

If you encounter issues:
1. Check Xcode build logs for detailed error messages
2. Verify all configuration steps above
3. Ensure your Apple Developer account is in good standing
4. Test the build process with a simple Flutter app first

Good luck with your app submission! 🎉
