# Bojang

A Tibetan Learning Flutter application.

## Getting Started

This project is a Flutter application for learning Tibetan language who already knows english.

### Prerequisites

- Flutter SDK (version ^3.7.2)
- Android Studio or VS Code
- Android SDK
- For iOS builds: Xcode (Mac only)

### Running the Application

#### Check Available Devices
To see all available devices and emulators:
```bash
flutter devices
```

#### Android Emulator
1. List available emulators:
```bash
flutter emulators
```

2. Launch an emulator (replace `Medium_Phone_API_36` with your emulator name):
```bash
flutter emulators --launch Medium_Phone_API_36
```

3. Run the app on the emulator:
```bash
flutter run -d emulator-5554
```
Note: The device ID (emulator-5554) might be different on your system. Check the device ID using `flutter devices`.

### Building the Application

#### Build Android APK
1. Install dependencies:
```bash
flutter pub get
```

2. Build release APK:
```bash
flutter build apk --release
```
The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

#### Optional: Build Split APKs by ABI
For smaller APK sizes, you can build split APKs:
```bash
flutter build apk --split-per-abi --release
```
This will generate three APKs:
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

#### Install on Android Device
To install the APK on a connected Android device:
```bash
flutter install
```

### Development Resources

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
