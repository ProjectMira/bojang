import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bojang/screens/lesson_complete_screen.dart';
import 'package:bojang/screens/quiz_screen.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';

/// Covers the one-attempt-per-question rule: a wrong answer is recorded and
/// the lesson moves on, so a finished lesson can score below 100%.
///
/// Lives apart from quiz_screen_test.dart because the tests there install
/// asset mocks that never release, and leave the audioplayers plugin in a
/// state that strands later answers.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Cache the real manifests before any asset mock is installed, so
    // google_fonts can still resolve them from behind the mock.
    await AssetManifest.loadFromAssetBundle(rootBundle);
  });

  /// Serves [contents] for [path]. rootBundle caches by key, so every test
  /// needs its own asset path.
  void mockQuizAsset(String path, String contents) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != path) return null;
          final bytes = Uint8List.fromList(utf8.encode(contents));
          return ByteData.view(bytes.buffer);
        });
  }

  /// Answering plays a sound, and an unmocked audioplayers channel never
  /// completes — which strands `_handleAnswer` before it can score.
  void mockAudioPlayers() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => 1);
    }
  }

  // Both services must be built eagerly: created lazily, ThemeService would
  // first exist at tap time with its defaults, before its preferences load.
  Widget wrapQuiz(String path) => MultiProvider(
    providers: [
      ChangeNotifierProvider<ProgressService>(
        lazy: false,
        create: (_) => ProgressService(),
      ),
      ChangeNotifierProvider<ThemeService>(
        lazy: false,
        create: (_) => ThemeService(),
      ),
    ],
    child: MaterialApp(home: QuizScreen(topicFilePath: path)),
  );

  /// Two questions: ཀ answered by "ka", ག answered by "ga".
  const twoQuestions = '''
  {
    "exercises": [
      {"tibetanText": "ཀ", "options": ["ka", "ga"], "correctAnswerIndex": 0},
      {"tibetanText": "ག", "options": ["ka", "ga"], "correctAnswerIndex": 1}
    ]
  }
  ''';

  Future<void> startQuiz(WidgetTester tester, String path) async {
    // Pre-unlock every achievement: an achievement dialog on completion would
    // sit over the screen under test and is not what these tests are about.
    SharedPreferences.setMockInitialValues({
      // Answer feedback plays a sound, and audioplayers neither resolves nor
      // fails reliably under test — turn it off so scoring is deterministic.
      'sound_effects_enabled': false,
      'unlocked_achievements': <String>[
        'first_quiz',
        'streak_3',
        'streak_7',
        'streak_30',
        'accuracy_80',
        'quiz_50',
      ],
    });
    mockAudioPlayers();
    mockQuizAsset(path, twoQuestions);
    await tester.pumpWidget(wrapQuiz(path));
    await tester.pump();
    // Enough frames for the quiz JSON and the ThemeService preferences to
    // both land before the first answer.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a wrong answer reveals the right one and moves on', (
    WidgetTester tester,
  ) async {
    const path = 'assets/quiz_data/level-1/vowels.json';
    await startQuiz(tester, path);

    expect(find.text('ཀ'), findsOneWidget);

    // "ga" is wrong for ཀ.
    await tester.tap(find.text('ga'));
    await tester.pump();

    expect(find.textContaining('not quite'), findsOneWidget);
    expect(find.textContaining('Answer: ka'), findsOneWidget);

    // The quiz advances instead of waiting for the learner to find the
    // correct option, and the wrong answer earns no score.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('ག'), findsOneWidget);
    expect(find.text('ཀ'), findsNothing);
    expect(find.text('Score: 0'), findsOneWidget);
  });

  testWidgets('a lesson with one mistake finishes below 100%', (
    WidgetTester tester,
  ) async {
    const path = 'assets/quiz_data/level-1/numbers.json';
    await startQuiz(tester, path);

    // First question wrong.
    await tester.tap(find.text('ga'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    // Let the next question's entrance animation finish, or the option is
    // still sliding and the tap lands on empty space.
    await tester.pump(const Duration(milliseconds: 400));

    // Second question right.
    await tester.ensureVisible(find.text('ga'));
    await tester.pump();
    await tester.tap(find.text('ga'));

    // Completion is async: the feedback delay, then the progress save and its
    // 600ms achievement window, then the route transition. Pump through them
    // explicitly — the celebration screen animates forever, so pumpAndSettle
    // would never return.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LessonCompleteScreen), findsOneWidget);
    expect(find.textContaining('You scored 1 of 2'), findsOneWidget);
    expect(find.text('Keep practicing!'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });
}
