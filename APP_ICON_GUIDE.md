# App Icon Update Guide for Bojang

## Overview
This guide provides instructions for updating both iOS and Android app icons to fix the current issues:
- **iOS**: Image is blurred - needs higher quality version
- **Android**: Icon doesn't fill the circle properly - needs adaptive icon implementation

## Current Issues & Solutions

### iOS App Icons
The current iOS icons appear blurred because they may not be created at the optimal resolution or have compression artifacts.

**Solution**: Replace all iOS app icon files with high-resolution versions generated from our SVG logo.

### Android App Icons  
The current Android icons don't fill the circle properly because they're not using Android's adaptive icon system.

**Solution**: Implement Android adaptive icons with proper foreground and background layers.

## Icon Specifications

### iOS App Icon Sizes Required:
- **1024×1024**: App Store (Icon-App-1024x1024@1x.png)
- **180×180**: iPhone @3x (Icon-App-60x60@3x.png)
- **120×120**: iPhone @2x (Icon-App-60x60@2x.png)
- **167×167**: iPad Pro @2x (Icon-App-83.5x83.5@2x.png)
- **152×152**: iPad @2x (Icon-App-76x76@2x.png)
- **76×76**: iPad @1x (Icon-App-76x76@1x.png)
- **120×120**: iPhone Spotlight @3x (Icon-App-40x40@3x.png)
- **80×80**: iPhone Spotlight @2x (Icon-App-40x40@2x.png)
- **40×40**: iPhone Spotlight @1x (Icon-App-40x40@1x.png)
- **87×87**: iPhone Settings @3x (Icon-App-29x29@3x.png)
- **58×58**: iPhone Settings @2x (Icon-App-29x29@2x.png)
- **29×29**: iPhone Settings @1x (Icon-App-29x29@1x.png)
- **60×60**: iPhone Notification @3x (Icon-App-20x20@3x.png)
- **40×40**: iPhone Notification @2x (Icon-App-20x20@2x.png)
- **20×20**: iPhone Notification @1x (Icon-App-20x20@1x.png)

### Android App Icon Sizes Required:
- **192×192**: xxxhdpi (ic_launcher.png)
- **144×144**: xxhdpi (ic_launcher.png)
- **96×96**: xhdpi (ic_launcher.png)
- **72×72**: hdpi (ic_launcher.png)
- **48×48**: mdpi (ic_launcher.png)

## Step-by-Step Instructions

### For iOS Icons:

1. **Export PNG from SVG**: Use the logo.svg file to generate PNG files at exact required dimensions
2. **Maintain aspect ratio**: Ensure the logo fills the square completely (iOS automatically applies corner radius)
3. **No transparency**: Use solid background colors
4. **Replace files**: Replace each icon file in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### For Android Icons:

1. **Create Adaptive Icons**: 
   - **Foreground**: 108×108dp with safe zone of 66×66dp in center for logo
   - **Background**: 108×108dp solid color background
   
2. **Update files in**:
   - `android/app/src/main/res/mipmap-*/ic_launcher.png`
   
3. **Create ic_launcher.xml** (if not exists):
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

## Quick Fix Commands

You can use online tools or command-line tools to generate icons:

### Using Online Tools (Recommended):
1. **App Icon Generator**: Upload your logo.svg to online generators like:
   - https://appicon.co/
   - https://makeappicon.com/
   - https://icon.kitchen/

2. **Upload the logo.svg** and download the generated icon sets

### Manual Export (Advanced):
Use tools like Inkscape, GIMP, or Adobe Illustrator to export the SVG at required dimensions.

## Files to Replace

### iOS Files:
Replace all PNG files in: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### Android Files:
Replace these files:
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` 
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`

## Testing

After updating icons:

1. **Clean build**:
```bash
flutter clean
flutter pub get
```

2. **Build and test**:
```bash
flutter build ios
flutter build android
```

3. **Install on devices** to verify icons appear correctly

## Design Notes

- The logo uses a green color scheme (#2E7D32, #4CAF50) with white Tibetan-inspired mandala patterns
- The design is circular-friendly and works well at small sizes
- The background color ensures good visibility on both light and dark device themes

## Troubleshooting

- **iOS icons still blurred**: Ensure you're using PNG files exported at exact pixel dimensions (not scaled)
- **Android icons not filling circle**: Verify you're using adaptive icons with proper foreground/background separation
- **Icons not updating**: Clear cache, clean build, and reinstall the app

---

**Next Steps**: Use an app icon generator tool with the provided logo.svg file to create all required icon sizes, then replace the existing files following this guide.

