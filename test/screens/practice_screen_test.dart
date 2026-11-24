import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bojang/screens/practice_screen.dart';
import 'package:bojang/services/learning_path_repository.dart';

/// The Practice tab's states: words due (spaced repetition), nothing due
/// (next review time), the kill switch / an older server (mistake and weak
/// words only), and nothing at all.
void main() {
  final now = DateTime(2026, 11, 24, 9);

  Map<String, dynamic> word(String id, String english, String label) => {
    'lexeme_id': id,
    'tibetan': 'ཆུ',
    'english': english,
    'label': label,
  };

  Map<String, dynamic> fsrsReview({
    int due = 3,
    int tracked = 42,
    DateTime? nextDue,
    List<Map<String, dynamic>>? flagged,
  }) {
    final words = flagged ?? [word('w1', 'water', 'mistake')];
    return {
      'word_count': words.length,
      'mistake_count': words.where((w) => w['label'] == 'mistake').length,
      'weak_count': words.where((w) => w['label'] == 'weak').length,
      'words': words,
      'fsrs_enabled': true,
      'due_count': due,
      'next_due_at': nextDue?.toUtc().toIso8601String(),
      'tracked_count': tracked,
      'session_size': due + words.length,
      'due_words': [
        for (var i = 0; i < due; i++) word('d$i', 'due word $i', 'due'),
      ],
    };
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(LearningPathRepository.debugReset);

  Future<void> pump(
    WidgetTester tester,
    Map<String, dynamic>? review, {
    bool? fsrs,
    ThemeMode mode = ThemeMode.light,
    Size? size,
  }) async {
    if (size != null) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    LearningPathRepository.fetchReview = () async => review;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: mode,
        home: PracticeScreen(fsrsEnabled: fsrs, clock: () => now),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('words due: count, Start button and words remembered', (
    tester,
  ) async {
    await pump(tester, fsrsReview(due: 3, tracked: 42));
    expect(find.text('3 words to review'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
    expect(find.text('You’re remembering 42 words'), findsOneWidget);
    // Due words listed first, then the mistake.
    final due = tester.getTopLeft(find.text('due word 0')).dy;
    final mistake = tester.getTopLeft(find.text('water')).dy;
    expect(due, lessThan(mistake));
    expect(find.text('Due'), findsNWidgets(3));
  });

  testWidgets('one word due reads singular', (tester) async {
    await pump(tester, fsrsReview(due: 1, tracked: 1, flagged: []));
    expect(find.text('1 word to review'), findsOneWidget);
    expect(find.text('You’re remembering 1 word'), findsOneWidget);
  });

  testWidgets('nothing due: next review time, no Start button', (tester) async {
    await pump(
      tester,
      fsrsReview(
        due: 0,
        tracked: 12,
        nextDue: now.add(const Duration(hours: 3)),
        flagged: [],
      ),
    );
    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('Next review in 3 h'), findsOneWidget);
    expect(find.text('You’re remembering 12 words'), findsOneWidget);
    expect(find.byKey(const ValueKey('review_start_button')), findsNothing);
  });

  testWidgets('nothing due tomorrow, mistakes left: practise them', (
    tester,
  ) async {
    await pump(tester, fsrsReview(due: 0, nextDue: DateTime(2026, 11, 25, 10)));
    expect(find.text('Next review tomorrow'), findsOneWidget);
    expect(find.text('Practise 1 tricky word'), findsOneWidget);
    expect(find.text('water'), findsOneWidget);
  });

  testWidgets('kill switch: mistake and weak words only, as before', (
    tester,
  ) async {
    await pump(tester, fsrsReview(due: 3, tracked: 42), fsrs: false);
    expect(find.text('1 word to review'), findsOneWidget);
    expect(find.textContaining('remembering'), findsNothing);
    expect(find.text('due word 0'), findsNothing);
    expect(find.text('Start review'), findsOneWidget);
  });

  testWidgets('an older server without FSRS fields still works', (
    tester,
  ) async {
    await pump(tester, {
      'word_count': 2,
      'mistake_count': 1,
      'weak_count': 1,
      'words': [word('w1', 'food', 'mistake'), word('w2', 'water', 'weak')],
    });
    expect(find.text('2 words to review'), findsOneWidget);
    expect(find.text('1 to fix · 1 weak'), findsOneWidget);
    expect(find.text('Start review'), findsOneWidget);
  });

  testWidgets('nothing learned yet', (tester) async {
    await pump(tester, fsrsReview(due: 0, tracked: 0, flagged: []));
    expect(find.text('Nothing to review yet'), findsOneWidget);
  });

  testWidgets('dark mode and iPad render without overflow', (tester) async {
    await pump(
      tester,
      fsrsReview(due: 5, tracked: 42),
      mode: ThemeMode.dark,
      size: const Size(1024, 1366),
    );
    expect(find.text('5 words to review'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
