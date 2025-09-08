import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/level_selection_screen.dart';

void main() {
  group('LevelSelectionScreen Simplified Tests', () {
    testWidgets('should display loading indicator initially', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Learn Tibetan'), findsOneWidget);
    });

    testWidgets('should display app bar with settings button', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));

      // Assert
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Learn Tibetan'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should have correct background color', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));

      // Assert
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFFF7F7F7)));
    });

    testWidgets('should handle data loading without crashing', (WidgetTester tester) async {
      const mockLevelsData = '''
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
              }
            ]
          }
        ]
      }
      ''';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString' &&
              methodCall.arguments == 'assets/quiz_data/levels.json') {
            return mockLevelsData;
          }
          return null;
        },
      );

      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
      await tester.pump(); // Process initial build
      await tester.pump(const Duration(seconds: 1)); // Allow data processing

      // Assert - Should load without crashing
      expect(tester.takeException(), isNull);
      
      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });

    testWidgets('should handle settings navigation', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
      
      // Tap settings icon
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();

      // Should navigate without crashing
      expect(tester.takeException(), isNull);
    });

    testWidgets('should handle loading errors gracefully', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          throw PlatformException(code: 'ASSET_NOT_FOUND', message: 'Asset not found');
        },
      );

      await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should handle errors without crashing
      expect(tester.takeException(), isNull);
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });
  });
}

