// Platform Test Configuration
//
// Configuration utilities for running tests across iOS and Android platforms

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Platform-specific test configuration
class PlatformTestConfig {
  /// Current platform being tested (defaulting to cross-platform)
  static String get currentPlatform => 'cross-platform';
  
  /// Platform-specific screen densities
  static const Map<String, double> platformDensities = {
    'iOS': 2.0,      // Retina displays
    'Android': 2.75, // Common Android density
  };
  
  /// Platform-specific device configurations
  static const Map<String, List<Map<String, dynamic>>> platformDevices = {
    'iOS': [
      {'name': 'iPhone SE', 'size': Size(320, 568), 'density': 2.0},
      {'name': 'iPhone 8', 'size': Size(375, 667), 'density': 2.0},
      {'name': 'iPhone 11', 'size': Size(414, 896), 'density': 2.0},
      {'name': 'iPhone 16 Plus', 'size': Size(428, 926), 'density': 3.0},
    ],
    'Android': [
      {'name': 'Android Small', 'size': Size(320, 533), 'density': 2.0},
      {'name': 'Android Medium', 'size': Size(360, 640), 'density': 2.75},
      {'name': 'Android Large', 'size': Size(411, 731), 'density': 2.75},
      {'name': 'Android XL', 'size': Size(428, 926), 'density': 3.0},
    ],
  };

  /// Sets up platform-specific mocks
  static void setupPlatformMocks() {
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
          return '/mock/Documents';
        } else if (methodCall.method == 'getTemporaryDirectory') {
          return '/mock/tmp';
        }
        return null;
      },
    );

    // Platform-specific device info
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/device_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getDeviceInfo') {
          return {'systemName': 'Test', 'systemVersion': '1.0.0'};
        }
        return null;
      },
    );
  }

  /// Cleans up platform-specific mocks
  static void cleanupPlatformMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter/platform'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/device_info'), null);
  }

  /// Test a widget on all supported devices for current platform
  static Future<void> testOnAllPlatformDevices(
    WidgetTester tester,
    Widget widget,
    Future<void> Function(WidgetTester, String) testFunction,
  ) async {
    final devices = platformDevices[currentPlatform] ?? [];
    
    for (final device in devices) {
      final size = device['size'] as Size;
      final density = device['density'] as double;
      final name = device['name'] as String;
      
      // Set screen size and density
      await tester.binding.setSurfaceSize(size);
      tester.binding.window.devicePixelRatioTestValue = density;
      
      // Run the test
      await testFunction(tester, name);
      
      // Reset
      await tester.binding.setSurfaceSize(null);
      tester.binding.window.clearDevicePixelRatioTestValue();
    }
  }

  /// Get platform-appropriate default theme data
  static Map<String, dynamic> getPlatformThemeDefaults() {
    return {
      'platform': TargetPlatform.android, // Default for testing
      'primarySwatch': 'blue',
      'fontFamily': 'Roboto',
    };
  }

  /// Platform-specific test timeouts
  static Duration getPlatformTimeout() {
    // Default timeout for testing
    return const Duration(seconds: 10);
  }
}

/// Extension for cross-platform testing utilities
extension CrossPlatformTester on WidgetTester {
  /// Pump and settle with platform-appropriate timeout
  Future<void> pumpAndSettleWithPlatformTimeout([
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    Duration? timeout,
  ]) async {
    return pumpAndSettle(
      duration, 
      phase, 
      timeout ?? PlatformTestConfig.getPlatformTimeout()
    );
  }

  /// Test responsive behavior across platform devices
  Future<void> testResponsiveBehavior(
    Widget widget,
    Future<void> Function(String deviceName) testCallback,
  ) async {
    await PlatformTestConfig.testOnAllPlatformDevices(
      this,
      widget,
      (tester, deviceName) async {
        await pumpWidget(widget);
        await pump();
        await testCallback(deviceName);
      },
    );
  }
}
