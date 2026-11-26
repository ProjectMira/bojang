// The app's main screens and how to reach each one, for the accessibility
// and screenshot tests.

import 'package:bojang/models/lesson_style.dart';
import 'package:bojang/screens/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

/// An existing learner: onboarding done, a few lessons, not a beginner.
Future<void> seedExistingLearner(SharedPreferences prefs, {bool dark = false}) async {
  final now = DateTime.now();
  await prefs.setString('onboarding_status', 'done');
  await prefs.setInt('lessons_completed', 6);
  await prefs.setInt('xp', 420);
  await prefs.setInt('total_quizzes', 6);
  await prefs.setInt('total_correct', 50);
  await prefs.setInt('current_streak', 2);
  await prefs.setString('last_play_date', now.toIso8601String());
  await prefs.setInt('learner_profile_asked_at', now.millisecondsSinceEpoch);
  await prefs.setString('animation_preference', 'off');
  await prefs.setBool('sound_effects_enabled', false);
  await prefs.setBool('app_theme', dark);
}

class AppScreen {
  const AppScreen(this.name, this.open);
  final String name;

  /// Shows the screen, starting from the main tabs with nothing pushed.
  final Future<void> Function(WidgetTester tester) open;
}

Future<void> showTab(WidgetTester tester, String name) =>
    tapIt(tester, find.text(name).last, settle: 2.5);

Future<void> backToTabs(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.popUntil((r) => r.isFirst);
  await wait(tester, 1);
}

final mainScreens = <AppScreen>[
  AppScreen('home', (t) => showTab(t, 'Home')),
  AppScreen('practice', (t) => showTab(t, 'Practice')),
  AppScreen('games', (t) => showTab(t, 'Games')),
  AppScreen('profile', (t) => showTab(t, 'Profile')),
  AppScreen('settings', (t) async {
    await showTab(t, 'Profile');
    await tapIt(t, find.byIcon(Icons.settings).first, settle: 2);
  }),
  AppScreen('leaderboard', (t) async {
    await showTab(t, 'Profile');
    await tapIt(t, find.byKey(const Key('profile-board-card')), settle: 3);
  }),
  AppScreen('topics', (t) async {
    await showTab(t, 'Home');
    await scrollTo(t, find.text('Browse all topics'));
    await tapText(t, 'Browse all topics', settle: 2.5);
  }),
  AppScreen('quiz', (t) async {
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'quiz'),
      builder: (_) => const QuizScreen(
        topicFilePath: 'api://level/vocab-animals',
        title: 'Animals',
        style: LessonStyle.words,
      ),
    ));
    await waitFor(t, find.byKey(const ValueKey('quiz-option-0')), timeout: 20);
    await wait(t, 1);
  }),
];

/// Visible text that was cut short (ellipsis / maxLines exceeded).
List<String> clippedTexts(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.didExceedMaxLines) {
      final s = o.text.toPlainText().replaceAll('\n', ' ').trim();
      if (s.isNotEmpty) out.add(s.length > 50 ? '${s.substring(0, 47)}...' : s);
    }
    o.visitChildren(visit);
  }

  for (final view in RendererBinding.instance.renderViews) {
    visit(view);
  }
  return out;
}

/// Short device name for file names: se / pro-max / ipad.
String deviceTag(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final shortest = size.shortestSide;
  if (shortest >= 700) return 'ipad-13';
  if (size.longestSide < 700) return 'iphone-se';
  if (shortest >= 430) return 'iphone-pro-max';
  return 'iphone-${shortest.round()}';
}
