import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bojang/screens/main_navigation_screen.dart';
import 'package:bojang/services/learning_path_repository.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';

/// Smoke test: the four main tabs (Home, Practice, Games, Profile) render
/// without throwing.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Offline: no path, no review words.
    LearningPathRepository.fetchPath = () async => null;
    LearningPathRepository.fetchReview = () async => null;
  });

  tearDown(LearningPathRepository.debugReset);

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

  testWidgets('home tab without a path shows the top bar and lesson hero', (tester) async {
    await pumpApp(tester);

    expect(find.text('Start a Lesson'), findsOneWidget);
    // The top bar: streak, daily goal ring, voice chip.
    expect(find.bySemanticsLabel(RegExp('day streak')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Daily goal')), findsOneWidget);
    expect(find.text('Cultural Tip'), findsOneWidget);
  });

  testWidgets('practice tab replaces the streak tab', (tester) async {
    await pumpApp(tester);
    expect(find.text('Streak'), findsNWidgets(1)); // the home stats row only
    await tester.tap(find.text('Practice'));
    await tester.pump(const Duration(seconds: 1));

    // Offline and signed out: the review explains itself and offers a retry.
    expect(find.text('Review needs an account'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('practice tab shows the words to review', (tester) async {
    LearningPathRepository.fetchReview = () async => {
      'word_count': 2,
      'mistake_count': 1,
      'weak_count': 1,
      'words': [
        {'lexeme_id': 'w1', 'tibetan': 'ཁ་ལག', 'english': 'food', 'label': 'mistake'},
        {'lexeme_id': 'w2', 'tibetan': 'ཆུ', 'english': 'water', 'label': 'weak'},
      ],
    };
    await pumpApp(tester);
    await tester.tap(find.text('Practice'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2 words to review'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
    expect(find.text('food'), findsOneWidget);
  });

  testWidgets('games tab lists only playable games', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games'));
    await tester.pump(const Duration(seconds: 1));

    // test/screens/games/games_test.dart checks all eight on a tall screen.
    expect(find.textContaining('8 games'), findsOneWidget);
    expect(find.text('Listen & Tap'), findsOneWidget);
    expect(find.text('Picture Pick'), findsOneWidget);
    expect(find.text('Match Pairs'), findsOneWidget);
    expect(find.text('Coming Soon'), findsNothing);
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
