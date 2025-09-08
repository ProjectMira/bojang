// Test Helpers for Bojang - Tibetan Learning App
//
// This file contains utility functions and mocks for testing
// Supports both iOS and Android platforms

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class to set up common test mocks and utilities
class TestHelpers {
  /// Mock levels data for testing
  static const String mockLevelsData = '''
  {
    "levels": [
      {
        "level": 1,
        "title": "Beginner",
        "sublevels": [
          {
            "level": "1.1",
            "name": "Alphabet",
            "path": "assets/quiz_data/level-1/alphabet.json"
          },
          {
            "level": "1.2",
            "name": "Vowels",
            "path": "assets/quiz_data/level-1/vowels.json"
          }
        ]
      },
      {
        "level": 2,
        "title": "Intermediate",
        "sublevels": [
          {
            "level": "2.1",
            "name": "Emotions",
            "path": "assets/quiz_data/level-2/emotions.json"
          }
        ]
      },
      {
        "level": 3,
        "title": "Advanced",
        "sublevels": []
      }
    ]
  }
  ''';

  /// Mock quiz data for testing
  static const String mockQuizData = '''
  {
    "title": "Alphabet",
    "questions": [
      {
        "tibetan": "ཀ",
        "english": "ka",
        "options": ["ka", "kha", "ga", "nga"],
        "correctAnswer": "ka"
      },
      {
        "tibetan": "ཁ",
        "english": "kha", 
        "options": ["ka", "kha", "ga", "nga"],
        "correctAnswer": "kha"
      }
    ]
  }
  ''';

  /// Sets up mock asset loading for tests
  static void setupAssetMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/assets'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'loadString') {
          final String assetPath = methodCall.arguments as String;
          
          if (assetPath == 'assets/quiz_data/levels.json') {
            return mockLevelsData;
          } else if (assetPath.startsWith('assets/quiz_data/level-')) {
            return mockQuizData;
          } else if (assetPath == 'assets/audio/correct.mp3') {
            return ''; // Mock audio file
          } else if (assetPath == 'assets/audio/incorrect.mp3') {
            return ''; // Mock audio file
          }
        }
        return null;
      },
    );
  }

  /// Cleans up asset mocks after tests
  static void cleanupAssetMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
  }

  /// Sets up mock method channel for notification service (both iOS and Android)
  static void setupNotificationMocks() {
    // Mock flutter_local_notifications (cross-platform)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_local_notifications'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') {
          return true;
        } else if (methodCall.method == 'zonedSchedule') {
          return null;
        } else if (methodCall.method == 'cancelAll') {
          return null;
        } else if (methodCall.method == 'requestPermissions') {
          return true; // iOS specific
        } else if (methodCall.method == 'getNotificationSettings') {
          return <String, dynamic>{
            'sound': true,
            'alert': true,
            'badge': true,
          };
        }
        return null;
      },
    );

    // Mock timezone initialization (cross-platform)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/timezone'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTimeZoneName') {
          return 'America/New_York'; // Default timezone
        }
        return null;
      },
    );

    // Mock audio players (cross-platform)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'play') {
          return {'playerId': 'test_player'};
        } else if (methodCall.method == 'stop') {
          return null;
        } else if (methodCall.method == 'pause') {
          return null;
        }
        return null;
      },
    );
  }

  /// Cleans up notification mocks
  static void cleanupNotificationMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter_local_notifications'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/timezone'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers'), null);
  }

  /// Sets up all common mocks
  static void setupAllMocks() {
    setupAssetMocks();
    setupNotificationMocks();
  }

  /// Cleans up all mocks
  static void cleanupAllMocks() {
    cleanupAssetMocks();
    cleanupNotificationMocks();
  }

  /// Waits for async operations with timeout
  static Future<void> waitForAsyncOperation(WidgetTester tester, {
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    await tester.pump();
    await tester.pump(timeout);
  }

  /// Pumps widget with proper setup for async operations
  static Future<void> pumpWidgetWithMocks(
    WidgetTester tester,
    Widget widget, {
    bool setupMocks = true,
  }) async {
    if (setupMocks) {
      setupAllMocks();
    }
    
    await tester.pumpWidget(widget);
    await waitForAsyncOperation(tester);
  }

  /// Test group setup with common mock setup
  static void setupTestGroup() {
    setUp(() {
      setupAllMocks();
      setupPlatformSpecificMocks();
    });

    tearDown(() {
      cleanupAllMocks();
      cleanupPlatformSpecificMocks();
    });
  }

  /// Sets up platform-specific mocks for iOS/Android compatibility
  static void setupPlatformSpecificMocks() {
    // Platform-specific system chrome settings
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/platform'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'SystemChrome.setSystemUIOverlayStyle') {
          return null;
        } else if (methodCall.method == 'SystemNavigator.pop') {
          return null;
        } else if (methodCall.method == 'HapticFeedback.vibrate') {
          return null;
        }
        return null;
      },
    );

    // Platform-specific path provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/mock/documents';
        } else if (methodCall.method == 'getTemporaryDirectory') {
          return '/mock/temp';
        }
        return null;
      },
    );
  }

  /// Cleans up platform-specific mocks
  static void cleanupPlatformSpecificMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter/platform'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  }

  /// Cross-platform device sizes for testing
  static const Map<String, List<Size>> platformScreenSizes = {
    'small': [
      Size(320, 568), // iPhone SE / Small Android
      Size(360, 640), // Android Compact
    ],
    'medium': [
      Size(375, 667), // iPhone 8
      Size(411, 731), // Android Standard
    ],
    'large': [
      Size(414, 896), // iPhone XR/11
      Size(428, 926), // iPhone Plus / Large Android
    ],
    'tablet': [
      Size(768, 1024), // iPad / Android Tablet
      Size(800, 1280), // Large Android Tablet
    ],
  };

  /// Test widget on multiple screen sizes (cross-platform)
  static Future<void> testOnMultipleScreenSizes(
    WidgetTester tester,
    Widget widget,
    Future<void> Function(Size screenSize, String category) testCallback,
  ) async {
    for (final category in platformScreenSizes.keys) {
      for (final size in platformScreenSizes[category]!) {
        await tester.binding.setSurfaceSize(size);
        await pumpWidgetWithMocks(tester, widget);
        await testCallback(size, category);
        await tester.binding.setSurfaceSize(null);
      }
    }
  }
}

/// Extension to make testing more convenient
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps and waits with timeout to avoid infinite waits
  Future<void> pumpWithTimeout([Duration duration = const Duration(milliseconds: 100)]) async {
    await pump();
    await pump(duration);
  }

  /// Finds text that may be in different widgets
  Finder findTextAnywhere(String text) {
    return find.textContaining(text);
  }
}
