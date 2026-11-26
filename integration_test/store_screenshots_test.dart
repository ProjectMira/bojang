// App Store screenshot harness. Not a test of behaviour: it walks the app
// through the screens worth showing and holds each one still, while
// `ci/scripts/store_screenshots.sh` captures the simulator at every marker.
//
// It pumps the screens directly instead of going through main(), so no
// notification prompt appears, and it seeds a few days of progress so the
// streak and XP are not all zeros. Lessons and games load words from
// whichever backend BOJANG_API_BASE_URL points at.
//
// Run through a script, not by hand:
//   ci/scripts/e2e.sh ... integration_test/store_screenshots_test.dart
//     local backend; part of every full e2e run; saves build/e2e/<run>/store/
//     <device>/ for iPhone 16 Pro Max (6.9") and iPad Pro 13". Pictures are
//     placeholders unless BOJANG_MEDIA_DIR has real ones.
//   ci/scripts/store_screenshots.sh <simulator-udid> <output-dir>
//     the live backend's real words and pictures.

import 'dart:convert';

import 'package:bojang/models/lesson_style.dart';
import 'package:bojang/screens/games/flashcards_game.dart';
import 'package:bojang/screens/games/match_pairs_game.dart';
import 'package:bojang/screens/games/picture_pick_game.dart';
import 'package:bojang/screens/games/word_builder_game.dart';
import 'package:bojang/screens/main_navigation_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import 'package:bojang/services/api_service.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> seedProgress() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  final today = DateTime.now();
  final days = [
    for (var i = 4; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
  await prefs.setInt('current_streak', 5);
  await prefs.setInt('longest_streak', 9);
  await prefs.setString('last_play_date', today.toIso8601String());
  await prefs.setStringList(
    'play_dates',
    days.map((d) => d.toIso8601String()).toList(),
  );
  await prefs.setInt('xp', 480);
  await prefs.setInt('total_quizzes', 60);
  await prefs.setInt('total_correct', 52);
  await prefs.setInt('completed_levels_count', 4);
  await prefs.setString(
    'category_progress',
    json.encode({
      'vocab-action': 0.9,
      'vocab-animals': 0.8,
      'vocab-fruits': 1.0,
      'vocab-colors': 0.5,
    }),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('store screenshots', (tester) async {
    await seedProgress();
    var serial = 0;

    /// Puts [screen] up as the whole app, fresh each time.
    Future<void> open(Widget screen) async {
      serial++;
      await tester.pumpWidget(
        MultiProvider(
          key: ValueKey('shot-$serial'),
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => ProgressService()),
            Provider<GoogleAuthService>(create: (_) => GoogleAuthService()),
            Provider<ApiService>(create: (_) => ApiService()),
          ],
          child: Consumer<ThemeService>(
            builder:
                (context, theme, _) => MaterialApp(
                  theme: theme.lightTheme,
                  debugShowCheckedModeBanner: false,
                  home: screen,
                ),
          ),
        ),
      );
    }

    /// Lets the network, images and animations run for [seconds].
    Future<void> wait(double seconds) async {
      final frames = (seconds * 10).round();
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Announces a screenshot and holds the screen while it is taken.
    Future<void> shot(String name) async {
      // ignore: avoid_print
      print('SHOT:$name');
      await wait(4);
    }

    /// Waits (up to 20 s: words come over the network) for [finder], then
    /// taps it.
    Future<void> tapFound(Finder finder) async {
      for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Long topic lists put some topics below the fold on a phone.
      await tester.ensureVisible(finder.first);
      await wait(0.5);
      await tester.tap(finder.first);
      await wait(0.5);
    }

    Future<void> tapText(String text) => tapFound(find.text(text));

    /// Home scrolls itself down to the current lesson; show it from the top
    /// (the streak and goal chips, the unit header).
    Future<void> homeFromTop() async {
      final list = find.byType(Scrollable).hitTestable();
      if (list.evaluate().isNotEmpty) {
        await tester.fling(list.first, const Offset(0, 3000), 4000);
        await wait(1.5);
      }
    }

    // 1. Home
    await open(const MainNavigationScreen());
    await wait(6);
    await homeFromTop();
    await shot('01-home');

    // 2. A picture question
    await open(
      const QuizScreen(
        topicFilePath: 'api://level/vocab-fruits',
        title: 'Fruits',
        style: LessonStyle.pictures,
      ),
    );
    await wait(6);
    await shot('02-lesson-picture');

    // 3. A listening question
    await open(
      const QuizScreen(
        topicFilePath: 'api://level/vocab-animals',
        title: 'Animals',
        style: LessonStyle.listening,
      ),
    );
    await wait(6);
    await shot('03-lesson-listening');

    // 4. The games list
    await open(const MainNavigationScreen());
    await wait(4);
    await tapText('Games');
    await wait(1);
    await shot('04-games');

    // 5. Listen & Tap
    await open(const ListenAndTapScreen());
    await wait(4);
    await tapText('Animals');
    await wait(7);
    await shot('05-listen-and-tap');

    // 6. Word Builder
    await open(const WordBuilderScreen());
    await wait(4);
    await tapText('Fruits');
    await wait(6);
    await shot('06-word-builder');

    // 7. Match Pairs
    await open(const MatchPairsScreen());
    await wait(4);
    await tapText('Animals');
    await wait(5);
    await shot('07-match-pairs');

    // 8. Flashcards, answer side
    await open(const FlashcardsScreen());
    await wait(4);
    await tapText('Animals');
    await wait(6);
    await tapText('Show meaning');
    await wait(2);
    await shot('08-flashcards');

    // 9. Streak: the streak sheet from Home's streak chip (there is no
    // Streak tab any more).
    await open(const MainNavigationScreen());
    await wait(4);
    await homeFromTop();
    final semantics = tester.ensureSemantics();
    await tapFound(find.bySemanticsLabel(RegExp('day streak')));
    semantics.dispose();
    await wait(1.5);
    await shot('09-streak');

    // ignore: avoid_print
    print('SHOT:done');
  });
}
