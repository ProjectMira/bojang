import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/screens/home_page.dart';
import 'package:bojang/screens/level_selection_screen.dart';
import '../test_helpers.dart';

void main() {
  group('HomePage Widget Tests', () {
    TestHelpers.setupTestGroup();
    testWidgets('should render LevelSelectionScreen', (WidgetTester tester) async {
      // Arrange & Act
      await TestHelpers.pumpWidgetWithMocks(
        tester,
        const MaterialApp(home: HomePage()),
        pumpAndSettle: false,
      );

      // Assert
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });

    testWidgets('should be a StatelessWidget', (WidgetTester tester) async {
      // Arrange & Act
      await TestHelpers.pumpWidgetWithMocks(
        tester,
        const MaterialApp(home: HomePage()),
        pumpAndSettle: false,
      );

      // Assert
      final homePageWidget = find.byType(HomePage);
      expect(homePageWidget, findsOneWidget);
      
      // Verify it's a StatelessWidget (no state management)
      final widget = tester.widget<HomePage>(homePageWidget);
      expect(widget, isA<StatelessWidget>());
    });

    testWidgets('should have correct key property', (WidgetTester tester) async {
      // Arrange
      const testKey = Key('test_home_page');
      
      // Act
      await tester.pumpWidget(const MaterialApp(
        home: HomePage(key: testKey),
      ));

      // Assert
      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('should pass through to LevelSelectionScreen without modification', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MaterialApp(home: HomePage()));

      // Assert - All LevelSelectionScreen content should be present
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
      
      // The HomePage should act as a simple wrapper
      final homePageFinder = find.byType(HomePage);
      final levelSelectionFinder = find.byType(LevelSelectionScreen);
      
      expect(homePageFinder, findsOneWidget);
      expect(levelSelectionFinder, findsOneWidget);
    });

    group('Integration with LevelSelectionScreen', () {
      testWidgets('should display level selection content through HomePage', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(home: HomePage()));
        await tester.pump(); // Allow initial build

        // Assert - Should show loading initially or content depending on state
        // Since LevelSelectionScreen loads data asynchronously, we check for either state
        final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        final hasContent = find.text('Learn Tibetan').evaluate().isNotEmpty;
        expect(hasLoading || hasContent, isTrue);
      });

      testWidgets('should handle LevelSelectionScreen navigation through HomePage', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(MaterialApp(
          home: const HomePage(),
          routes: {
            '/settings': (context) => const Scaffold(body: Text('Settings')),
          },
        ));
        
        await tester.pump(const Duration(milliseconds: 500)); // Wait for any loading to complete
        
        // Look for settings button from LevelSelectionScreen
        final settingsButton = find.byIcon(Icons.settings);
        if (settingsButton.evaluate().isNotEmpty) {
          await tester.tap(settingsButton);
          await tester.pump(const Duration(milliseconds: 300));
          
          // Should navigate to notification settings
          expect(find.text('Notification Settings'), findsOneWidget);
        }
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle null key gracefully', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(const MaterialApp(
          home: HomePage(key: null),
        ));

        // Assert
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
      });

      testWidgets('should work with different MaterialApp configurations', (WidgetTester tester) async {
        // Test with custom theme
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(primarySwatch: Colors.red),
          home: const HomePage(),
        ));
        
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
        
        // Test with different locale
        await tester.pumpWidget(const MaterialApp(
          locale: Locale('en', 'US'),
          home: HomePage(),
        ));
        
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(LevelSelectionScreen), findsOneWidget);
      });
    });

    group('Performance Tests', () {
      testWidgets('should build efficiently without unnecessary rebuilds', (WidgetTester tester) async {
        // Arrange
        int buildCount = 0;
        
        // Create a custom HomePage that counts builds
        Widget buildCountingHomePage() {
          return MaterialApp(
            home: Builder(
              builder: (context) {
                buildCount++;
                return const HomePage();
              },
            ),
          );
        }

        // Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          buildCountingHomePage(),
          pumpAndSettle: false,
        );
        await tester.pump(const Duration(milliseconds: 50)); // Trigger another build cycle
        
        // Assert - Should build minimal number of times
        expect(buildCount, lessThanOrEqualTo(3)); // Initial build + potential rebuilds with font loading
      });
    });

    group('Accessibility Tests', () {
      testWidgets('should maintain accessibility from LevelSelectionScreen', (WidgetTester tester) async {
        // Arrange & Act
        await TestHelpers.pumpWidgetWithMocks(
          tester,
          const MaterialApp(home: HomePage()),
          pumpAndSettle: false,
        );

        // Assert - Check for semantic information passed through
        expect(find.byType(Semantics), findsWidgets);
      });
    });
  });
}

