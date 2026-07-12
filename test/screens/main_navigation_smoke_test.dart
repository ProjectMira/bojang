import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bojang/screens/main_navigation_screen.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';

/// Smoke test: the four main tabs render without throwing.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => ProgressService()),
          Provider<GoogleAuthService>(create: (_) => GoogleAuthService()),
        ],
        child: const MaterialApp(home: MainNavigationScreen()),
      ),
    );
    // Let async prefs loads and entrance animations settle.
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('home tab shows the lesson hero as primary CTA', (tester) async {
    await pumpApp(tester);

    expect(find.text('Start a Lesson'), findsOneWidget);
    expect(find.text('Ready for Tibetan?'), findsOneWidget);
    expect(find.text('Cultural Tip'), findsOneWidget);
  });

  testWidgets('streak tab renders habit view', (tester) async {
    await pumpApp(tester);
    // 'Streak' also appears in the home stats row; the nav item renders last.
    await tester.tap(find.text('Streak').last);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Next Milestone'), findsOneWidget);
    expect(find.text('Practice Now'), findsOneWidget);
  });

  testWidgets('games tab lists only playable games', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Memory Match'), findsOneWidget);
    expect(find.text('Speed Quiz'), findsOneWidget);
    expect(find.text('Coming Soon'), findsNothing);
    expect(find.text('Word Builder'), findsNothing);
    expect(find.text('Audio Challenge'), findsNothing);
    expect(find.text('Story Mode'), findsNothing);
    expect(find.text('Daily Challenge'), findsNothing);
  });

  testWidgets('profile tab renders', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
