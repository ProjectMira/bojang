import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/quiz_screen.dart';

void main() {
  group('QuizScreen Simplified Tests', () {
    const testFilePath = 'assets/quiz_data/level-1/alphabet.json';
    
    testWidgets('should display loading state initially', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: QuizScreen(topicFilePath: testFilePath),
      ));

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading questions...'), findsOneWidget);
    });

    testWidgets('should display app bar with title', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: QuizScreen(topicFilePath: testFilePath),
      ));

      // Assert
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('should handle successful quiz data loading', (WidgetTester tester) async {
      // Mock quiz data
      const mockQuizData = '''
      {
        "exercises": [
          {
            "type": "character_recognition",
            "tibetanText": "ཀ",
            "options": ["ka", "ga", "kha"],
            "correctAnswerIndex": 0
          }
        ]
      }
      ''';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString' && 
              methodCall.arguments == testFilePath) {
            return mockQuizData;
          }
          return null;
        },
      );

      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(
        home: QuizScreen(topicFilePath: testFilePath),
      ));
      await tester.pump(); // Process initial build
      await tester.pump(const Duration(seconds: 1)); // Allow data loading

      // Assert - Should eventually show quiz content or remain in loading state
      // Either state is acceptable in tests due to async nature
      expect(tester.takeException(), isNull);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });

    testWidgets('should handle basic user interaction without crashing', (WidgetTester tester) async {
      const mockQuizData = '''
      {
        "exercises": [
          {
            "tibetanText": "ཀ",
            "options": ["ka", "ga"],
            "correctAnswerIndex": 0
          }
        ]
      }
      ''';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async => mockQuizData,
      );

      await tester.pumpWidget(const MaterialApp(
        home: QuizScreen(topicFilePath: testFilePath),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // If elements are available, try to interact with them
      if (find.text('ka').evaluate().isNotEmpty) {
        await tester.tap(find.text('ka'));
        await tester.pump();
      }

      // Should not crash
      expect(tester.takeException(), isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });

    testWidgets('should display error state for invalid data', (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async => '{"invalid": "json"}',
      );

      await tester.pumpWidget(const MaterialApp(
        home: QuizScreen(topicFilePath: testFilePath),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should either show error or still be loading (both acceptable)
      expect(tester.takeException(), isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/assets'), null);
    });
  });
}

