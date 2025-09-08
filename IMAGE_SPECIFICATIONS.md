# Bojang App - Required Image Specifications

## Overview
This document lists all required image sizes and formats for the Bojang app. All images should be high-quality PNG format with transparent backgrounds where noted.

---

## 📱 iOS App Icons
**Location**: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`  
**Format**: PNG (no transparency allowed)  
**Background**: Must fill entire square (iOS applies corner radius automatically)

| Filename | Size (pixels) | Usage |
|----------|---------------|-------|
| `Icon-App-1024x1024@1x.png` | 1024 × 1024 | App Store |
| `Icon-App-180x180@1x.png` | 180 × 180 | iPhone @3x |
| `Icon-App-120x120@1x.png` | 120 × 120 | iPhone @2x |
| `Icon-App-167x167@1x.png` | 167 × 167 | iPad Pro @2x |
| `Icon-App-152x152@1x.png` | 152 × 152 | iPad @2x |
| `Icon-App-76x76@1x.png` | 76 × 76 | iPad @1x |
| `Icon-App-87x87@1x.png` | 87 × 87 | Settings @3x |
| `Icon-App-58x58@1x.png` | 58 × 58 | Settings @2x |
| `Icon-App-29x29@1x.png` | 29 × 29 | Settings @1x |
| `Icon-App-80x80@1x.png` | 80 × 80 | Spotlight @2x |
| `Icon-App-40x40@1x.png` | 40 × 40 | Spotlight @1x |
| `Icon-App-60x60@1x.png` | 60 × 60 | Notification @3x |
| `Icon-App-40x40@1x.png` | 40 × 40 | Notification @2x |
| `Icon-App-20x20@1x.png` | 20 × 20 | Notification @1x |

**Note**: The actual filenames in the directory are different. Here are the actual filenames:

| Actual Filename | Size | 
|-----------------|------|
| `Icon-App-20x20@1x.png` | 20 × 20 |
| `Icon-App-20x20@2x.png` | 40 × 40 |
| `Icon-App-20x20@3x.png` | 60 × 60 |
| `Icon-App-29x29@1x.png` | 29 × 29 |
| `Icon-App-29x29@2x.png` | 58 × 58 |
| `Icon-App-29x29@3x.png` | 87 × 87 |
| `Icon-App-40x40@1x.png` | 40 × 40 |
| `Icon-App-40x40@2x.png` | 80 × 80 |
| `Icon-App-40x40@3x.png` | 120 × 120 |
| `Icon-App-60x60@2x.png` | 120 × 120 |
| `Icon-App-60x60@3x.png` | 180 × 180 |
| `Icon-App-76x76@1x.png` | 76 × 76 |
| `Icon-App-76x76@2x.png` | 152 × 152 |
| `Icon-App-83.5x83.5@2x.png` | 167 × 167 |
| `Icon-App-1024x1024@1x.png` | 1024 × 1024 |

---

## 🤖 Android App Icons
**Location**: `android/app/src/main/res/mipmap-[density]/`  
**Format**: PNG (no transparency allowed)  
**Background**: Must fill entire square (Android applies shapes automatically)

| Directory | Filename | Size (pixels) | Density |
|-----------|----------|---------------|---------|
| `mipmap-mdpi/` | `ic_launcher.png` | 48 × 48 | mdpi |
| `mipmap-hdpi/` | `ic_launcher.png` | 72 × 72 | hdpi |
| `mipmap-xhdpi/` | `ic_launcher.png` | 96 × 96 | xhdpi |
| `mipmap-xxhdpi/` | `ic_launcher.png` | 144 × 144 | xxhdpi |
| `mipmap-xxxhdpi/` | `ic_launcher.png` | 192 × 192 | xxxhdpi |

---

## 🎨 Splash Screen Logo
**Location**: `assets/app_icons/`  
**Format**: PNG with transparent background OR solid background  
**Usage**: Displayed in circular container in splash screen

| Filename | Size (pixels) | Purpose |
|----------|---------------|---------|
| `bojang_logo.png` | 512 × 512 (minimum) | Splash screen logo |

**Note**: This will be displayed in a 200×200 circular container, so ensure the logo looks good when cropped to circle.

---

## 📏 Design Guidelines

### iOS Icons:
- **Fill entire square** - iOS automatically applies corner radius
- **No transparency** - Use solid background
- **High contrast** - Works on both light and dark backgrounds
- **Crisp details** - Avoid very thin lines that may disappear at small sizes

### Android Icons:
- **Fill entire square** - Android applies various shapes (circle, square, etc.)
- **No transparency** - Use solid background  
- **Safe area** - Keep important content within center 80% for adaptive icons
- **High contrast** - Works with device themes

### Splash Screen Logo:
- **Circular safe area** - Design should look good when cropped to circle
- **High resolution** - Use at least 512×512 for crisp display
- **Transparent OR solid background** - Your choice based on design

---

## 🛠️ Quick Setup Commands

After you provide the images, I'll update the code to use them:

```bash
# 1. Clean build
flutter clean && flutter pub get

# 2. Test the app
flutter run

# 3. Build for production
flutter build ios
flutter build android
```

---

## 📁 File Structure Expected

```
bojang/
├── ios/Runner/Assets.xcassets/AppIcon.appiconset/
│   ├── Icon-App-20x20@1x.png (20×20)
│   ├── Icon-App-20x20@2x.png (40×40)
│   ├── Icon-App-20x20@3x.png (60×60)
│   ├── Icon-App-29x29@1x.png (29×29)
│   ├── Icon-App-29x29@2x.png (58×58)
│   ├── Icon-App-29x29@3x.png (87×87)
│   ├── Icon-App-40x40@1x.png (40×40)
│   ├── Icon-App-40x40@2x.png (80×80)
│   ├── Icon-App-40x40@3x.png (120×120)
│   ├── Icon-App-60x60@2x.png (120×120)
│   ├── Icon-App-60x60@3x.png (180×180)
│   ├── Icon-App-76x76@1x.png (76×76)
│   ├── Icon-App-76x76@2x.png (152×152)
│   ├── Icon-App-83.5x83.5@2x.png (167×167)
│   └── Icon-App-1024x1024@1x.png (1024×1024)
├── android/app/src/main/res/
│   ├── mipmap-mdpi/ic_launcher.png (48×48)
│   ├── mipmap-hdpi/ic_launcher.png (72×72)
│   ├── mipmap-xhdpi/ic_launcher.png (96×96)
│   ├── mipmap-xxhdpi/ic_launcher.png (144×144)
│   └── mipmap-xxxhdpi/ic_launcher.png (192×192)
└── assets/app_icons/
    └── bojang_logo.png (512×512 minimum)
```

---

## 🎯 Priority Order

1. **Splash Screen Logo** - `assets/app_icons/bojang_logo.png` (512×512)
2. **iOS Primary** - `Icon-App-1024x1024@1x.png` (1024×1024) 
3. **Android Primary** - `mipmap-xxxhdpi/ic_launcher.png` (192×192)
4. **All other sizes** - Can be generated from the primary ones

Once you provide these images, I'll integrate them into the app and ensure everything works perfectly!
