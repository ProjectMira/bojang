// Test Helpers for Bojang - Tibetan Learning App
//
// This file contains utility functions and mocks for testing
// Supports both iOS and Android platforms

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

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

  /// Comprehensive asset mocking that handles all asset types
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
          } else if (assetPath == 'AssetManifest.json') {
            return '''
            {
              "assets/quiz_data/levels.json": ["assets/quiz_data/levels.json"],
              "packages/google_fonts/fonts/Kalam-Regular.ttf": ["packages/google_fonts/fonts/Kalam-Regular.ttf"],
              "packages/google_fonts/fonts/Kalam-Bold.ttf": ["packages/google_fonts/fonts/Kalam-Bold.ttf"]
            }
            ''';
          } else if (assetPath == 'AssetManifest.bin') {
            return Uint8List(0);
          } else if (assetPath == 'FontManifest.json') {
            return '''
            [
              {
                "family": "Kalam",
                "fonts": [
                  {"asset": "packages/google_fonts/fonts/Kalam-Regular.ttf"},
                  {"asset": "packages/google_fonts/fonts/Kalam-Bold.ttf", "weight": 700}
                ]
              }
            ]
            ''';
          } else if (assetPath.contains('google_fonts') || assetPath.contains('Kalam')) {
            return ''; // Mock font content
          }
        } else if (methodCall.method == 'load') {
          // Handle binary asset loading (fonts, images)
          return Uint8List.fromList([0, 0, 0, 0]); // Minimal data
        }
        return null;
      },
    );
  }

  /// Set up comprehensive platform mocking
  static void setupPlatformMocks() {
    // System Chrome and platform services
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/platform'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'SystemChrome.setApplicationSwitcherDescription':
          case 'SystemChrome.setSystemUIOverlayStyle':
          case 'SystemNavigator.pop':
          case 'HapticFeedback.vibrate':
          case 'Clipboard.setData':
            return null;
          case 'Clipboard.getData':
            return <String, dynamic>{'text': ''};
          default:
            return null;
        }
      },
    );

    // Additional SystemChrome mocking with proper method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/platform_views'),
      (MethodCall methodCall) async => null,
    );

    // Connectivity
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') return 'none';
        return null;
      },
    );

    // Path provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getApplicationDocumentsDirectory':
            return '/mock/documents';
          case 'getTemporaryDirectory':
            return '/mock/temp';
          default:
            return null;
        }
      },
    );
  }

  /// Set up Google Fonts mocking to prevent network requests and font loading issues
  static void setupGoogleFontsMocks() {
    // Mock the Google Fonts plugin channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_fonts'),
      (MethodCall methodCall) async => null,
    );

    // Mock HTTP requests for fonts
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/http'),
      (MethodCall methodCall) async => null,
    );
  }

  /// Set up notification service mocks
  static void setupNotificationMocks() {
    // Flutter local notifications
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_local_notifications'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'initialize':
            return true;
          case 'zonedSchedule':
          case 'cancelAll':
            return null;
          case 'requestPermissions':
            return true;
          case 'getNotificationSettings':
            return <String, dynamic>{
              'sound': true,
              'alert': true,
              'badge': true,
            };
          default:
            return null;
        }
      },
    );

    // Timezone
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/timezone'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTimeZoneName') {
          return 'America/New_York';
        }
        return null;
      },
    );

    // Audio players
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'play':
            return {'playerId': 'test_player'};
          case 'stop':
          case 'pause':
            return null;
          default:
            return null;
        }
      },
    );
  }

  /// Set up all mocks at once
  static void setupAllMocks() {
    setupAssetMocks();
    setupPlatformMocks();
    setupGoogleFontsMocks();
    setupNotificationMocks();
  }

  /// Clean up all mocks
  static void cleanupAllMocks() {
    final channels = [
      'flutter/assets',
      'flutter/platform',
      'flutter/platform_views',
      'plugins.flutter.io/connectivity',
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/google_fonts',
      'plugins.flutter.io/http',
      'flutter_local_notifications',
      'plugins.flutter.io/timezone',
      'xyz.luan/audioplayers',
    ];

    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  }

  /// Pump widget with proper setup and timeout handling
  static Future<void> pumpWidgetWithMocks(
    WidgetTester tester,
    Widget widget, {
    bool setupMocks = true,
    Duration timeout = const Duration(seconds: 4), // Increased timeout for splash screen
  }) async {
    if (setupMocks) {
      setupAllMocks();
    }
    
    await tester.pumpWidget(widget);
    
    // Allow async operations to complete with proper timeout for animations
    await tester.pump();
    await tester.pump(timeout);
    
    // Additional pumps to ensure all async operations complete
    await tester.pumpAndSettle(timeout);
  }

  /// Wait for async operations with proper timeout
  static Future<void> waitForAsync(WidgetTester tester, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    await tester.pump();
    await tester.pump(timeout);
    await tester.pumpAndSettle(timeout);
  }

  /// Test group setup with mocks
  static void setupTestGroup() {
    setUp(() {
      setupAllMocks();
    });

    tearDown(() {
      cleanupAllMocks();
    });
  }

  /// Mock asset loading with custom data
  static void mockAssetString(String path, String content) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/assets'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'loadString' && methodCall.arguments == path) {
          return content;
        }
        return null;
      },
    );
  }
}

/// Extension to make testing more convenient
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps and waits with reasonable timeout
  Future<void> pumpWithTimeout([Duration duration = const Duration(seconds: 4)]) async {
    await pump();
    await pump(duration);
    await pumpAndSettle(duration);
  }

  /// Finds text anywhere in the widget tree
  Finder findTextAnywhere(String text) {
    return find.textContaining(text);
  }
}