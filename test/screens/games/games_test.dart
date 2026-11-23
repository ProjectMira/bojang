import 'dart:math';

import 'package:bojang/models/game_word.dart';
import 'package:bojang/models/lesson_style.dart';
import 'package:bojang/screens/extra_games_screen.dart';
import 'package:bojang/screens/games/flashcards_game.dart';
import 'package:bojang/screens/games/game_host.dart';
import 'package:bojang/screens/games/game_widgets.dart';
import 'package:bojang/screens/games/match_pairs_game.dart';
import 'package:bojang/screens/games/picture_pick_game.dart';
import 'package:bojang/screens/games/true_false_game.dart';
import 'package:bojang/screens/games/word_builder_game.dart';
import 'package:bojang/services/game_words_repository.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';
import 'package:bojang/widgets/lesson_style_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ten two-syllable words with no picture and no recording, so the games
/// run without touching the network or the audio plugin.
final List<GameWord> tenWords = [
  for (final (i, entry) in const [
    ('ཀུ་ཤུ', 'apple'),
    ('ཆུ་ཚོད', 'clock'),
    ('ཁ་ལག', 'food'),
    ('ཉི་མ', 'sun'),
    ('ཟླ་བ', 'moon'),
    ('མེ་ཏོག', 'flower'),
    ('སློབ་གྲྭ', 'school'),
    ('དཔེ་ཆ', 'book'),
    ('ཨ་མ', 'mother'),
    ('པ་ལགས', 'father'),
  ].indexed)
    GameWord(id: 'w$i', tibetan: '${entry.$1}།', english: entry.$2),
];

class FakeRepository extends GameWordsRepository {
  final List<GameTopic> topics;
  final Map<String, List<GameWord>> words;

  const FakeRepository({required this.topics, required this.words});

  @override
  Future<List<GameTopic>> loadTopics() async => topics;

  @override
  Future<List<GameWord>> loadWords(String topicId) async =>
      words[topicId] ?? const [];
}

void main() {
  late ThemeService theme;
  late ProgressService progress;

  setUp(() {
    // Sound effects off: the chime player is a platform plugin. Achievements
    // pre-unlocked so no dialog opens over a result screen.
    SharedPreferences.setMockInitialValues({'sound_effects_enabled': false});
    theme = ThemeService();
    progress = ProgressService();
  });

  Future<void> pumpGame(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeService>.value(value: theme),
          ChangeNotifierProvider<ProgressService>.value(value: progress),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    // Let the services read their (mocked) preferences.
    await tester.pump(const Duration(milliseconds: 100));
  }

  GameRound roundOf(List<GameWord> words, void Function(GameResult) done) =>
      GameRound(words: words, topicName: 'Test', onFinished: done);

  group('Match Pairs', () {
    Future<void> match(WidgetTester tester, String left, String right) async {
      await tester.tap(find.byKey(ValueKey('left-$left')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('right-$right')));
      await tester.pump();
    }

    testWidgets('clearing both boards cleanly scores every pair', (
      tester,
    ) async {
      GameResult? result;
      await pumpGame(
        tester,
        MatchPairsGame(
          round: roundOf(tenWords, (r) => result = r),
          random: Random(1),
        ),
      );

      expect(find.text('Board 1 of 2'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await match(tester, 'w$i', 'w$i');
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Board 2 of 2'), findsOneWidget);
      expect(result, isNull);

      for (var i = 5; i < 10; i++) {
        await match(tester, 'w$i', 'w$i');
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(result!.correct, 10);
      expect(result!.total, 10);
    });

    testWidgets('a wrong guess costs both words their first-try point', (
      tester,
    ) async {
      GameResult? result;
      await pumpGame(
        tester,
        MatchPairsGame(
          round: roundOf(tenWords.take(5).toList(), (r) => result = r),
          random: Random(1),
        ),
      );

      await match(tester, 'w0', 'w1');
      // The red flash clears before the board accepts taps again.
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 5; i++) {
        await match(tester, 'w$i', 'w$i');
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(result!.correct, 3);
      expect(result!.total, 5);
    });
  });

  group('Picture Pick', () {
    testWidgets('picking the right tile every time scores the round', (
      tester,
    ) async {
      GameResult? result;
      await pumpGame(
        tester,
        PicturePickGame(
          round: roundOf(tenWords, (r) => result = r),
          prompt: PicturePrompt.read,
          random: Random(2),
        ),
      );

      for (var i = 0; i < 10; i++) {
        expect(find.text(tenWords[i].tibetan), findsOneWidget);
        expect(find.byType(InkWell), findsNWidgets(4));
        await tester.tap(find.byKey(ValueKey('$i-w$i')));
        await tester.pump(const Duration(milliseconds: 1400));
      }
      expect(result!.correct, 10);
      expect(result!.total, 10);
    });

    testWidgets('a wrong pick is not scored and the answer is labelled', (
      tester,
    ) async {
      GameResult? result;
      await pumpGame(
        tester,
        PicturePickGame(
          round: roundOf(tenWords.take(4).toList(), (r) => result = r),
          prompt: PicturePrompt.read,
          random: Random(2),
        ),
      );

      // With four words every other word is a decoy on the first question.
      await tester.tap(find.byKey(const ValueKey('0-w1')));
      await tester.pump(const Duration(milliseconds: 2100));
      for (var i = 1; i < 4; i++) {
        await tester.tap(find.byKey(ValueKey('$i-w$i')));
        await tester.pump(const Duration(milliseconds: 1400));
      }
      expect(result!.correct, 3);
      expect(result!.total, 4);
    });

    testWidgets('the listening game hides the written word until answered', (
      tester,
    ) async {
      await pumpGame(
        tester,
        PicturePickGame(
          round: roundOf(tenWords, (_) {}),
          prompt: PicturePrompt.listen,
          random: Random(2),
        ),
      );
      expect(find.text('Tap what you hear'), findsOneWidget);
      expect(find.text(tenWords[0].tibetan).hitTestable(), findsNothing);

      await tester.tap(find.byKey(const ValueKey('0-w0')));
      await tester.pump();
      expect(find.text(tenWords[0].tibetan), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1400));
    });
  });

  group('Word Builder', () {
    Future<void> build(WidgetTester tester, List<String> syllables) async {
      for (final syllable in syllables) {
        await tester.tap(find.text(syllable).first);
        await tester.pump();
      }
    }

    testWidgets('spelling each word in order scores the round', (tester) async {
      GameResult? result;
      await pumpGame(
        tester,
        WordBuilderGame(
          round: roundOf(tenWords, (r) => result = r),
          random: Random(3),
        ),
      );

      for (var i = 0; i < WordBuilderGame.maxQuestions; i++) {
        expect(find.text(tenWords[i].english), findsOneWidget);
        await build(tester, tenWords[i].syllables);
        await tester.pump(const Duration(milliseconds: 1600));
      }
      expect(result!.correct, WordBuilderGame.maxQuestions);
      expect(result!.total, WordBuilderGame.maxQuestions);
    });

    testWidgets('two wrong orders reveal the word and score nothing', (
      tester,
    ) async {
      GameResult? result;
      final words = tenWords.take(4).toList();
      await pumpGame(
        tester,
        WordBuilderGame(
          round: roundOf(words, (r) => result = r),
          random: Random(3),
        ),
      );

      final reversed = words[0].syllables.reversed.toList();
      await build(tester, reversed);
      await tester.pump(const Duration(milliseconds: 800));
      await build(tester, reversed);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('It is spelled like this.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2300));

      for (var i = 1; i < 4; i++) {
        await build(tester, words[i].syllables);
        await tester.pump(const Duration(milliseconds: 1600));
      }
      expect(result!.correct, 3);
      expect(result!.total, 4);
    });

    testWidgets('syllable tiles sit side by side, not one per row', (
      tester,
    ) async {
      await pumpGame(
        tester,
        WordBuilderGame(round: roundOf(tenWords, (_) {}), random: Random(3)),
      );
      final syllables = tenWords[0].syllables;
      final first = tester.getRect(find.text(syllables[0]));
      final second = tester.getRect(find.text(syllables[1]));
      expect(first.center.dy, moreOrLessEquals(second.center.dy, epsilon: 1));
      // Each tile hugs its syllable instead of filling the 800px test screen.
      final tile = tester.getSize(
        find.ancestor(of: find.text(syllables[0]), matching: find.byType(InkWell)),
      );
      expect(tile.width, lessThan(160));
    });

    test('only words with two to five syllables can be built', () {
      GameWord w(String t) => GameWord(id: t, tibetan: t, english: 'x');
      expect(WordBuilderGame.canBuild(w('ཨམ།')), isFalse);
      expect(WordBuilderGame.canBuild(w('ཁ་ལག')), isTrue);
      expect(WordBuilderGame.canBuild(w('ཀ་ཁ་ག་ང་ཅ')), isTrue);
      expect(WordBuilderGame.canBuild(w('ཀ་ཁ་ག་ང་ཅ་ཆ')), isFalse);
    });
  });

  group('True or False', () {
    testWidgets('judging every card correctly scores the round', (
      tester,
    ) async {
      GameResult? result;
      await pumpGame(
        tester,
        TrueFalseGame(
          round: roundOf(tenWords, (r) => result = r),
          random: Random(4),
        ),
      );

      var sawFalseClaim = false;
      for (var i = 0; i < 10; i++) {
        expect(find.text(tenWords[i].tibetan), findsOneWidget);
        final claimIsTrue = find.text(tenWords[i].english).evaluate().isNotEmpty;
        sawFalseClaim |= !claimIsTrue;
        await tester.tap(find.text(claimIsTrue ? 'True' : 'False'));
        await tester.pump();
        expect(find.text('Right!'), findsOneWidget);
        expect(find.text('It means: ${tenWords[i].english}'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1200));
      }
      expect(sawFalseClaim, isTrue, reason: 'seed should mix in false claims');
      expect(result!.correct, 10);
      expect(result!.total, 10);
    });

    testWidgets('a wrong call shows the real meaning and is not scored', (
      tester,
    ) async {
      GameResult? result;
      await pumpGame(
        tester,
        TrueFalseGame(
          round: roundOf(tenWords.take(4).toList(), (r) => result = r),
          random: Random(4),
        ),
      );

      for (var i = 0; i < 4; i++) {
        final claimIsTrue = find.text(tenWords[i].english).evaluate().isNotEmpty;
        // Answer the first card wrongly, the rest correctly.
        final sayTrue = i == 0 ? !claimIsTrue : claimIsTrue;
        await tester.tap(find.text(sayTrue ? 'True' : 'False'));
        await tester.pump();
        if (i == 0) {
          expect(find.text('Not quite'), findsOneWidget);
          expect(find.text('It means: ${tenWords[0].english}'), findsOneWidget);
        }
        await tester.pump(const Duration(milliseconds: 2200));
      }
      expect(result!.correct, 3);
      expect(result!.total, 4);
    });
  });

  group('Flashcards', () {
    testWidgets('a missed card comes back and is not counted as known', (
      tester,
    ) async {
      GameResult? result;
      final words = tenWords.take(3).toList();
      await pumpGame(
        tester,
        FlashcardsGame(round: roundOf(words, (r) => result = r)),
      );

      // The meaning stays hidden until the card is flipped.
      expect(find.text(words[0].tibetan), findsOneWidget);
      expect(find.text(words[0].english), findsNothing);
      await tester.tap(find.text('Show meaning'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(words[0].english), findsOneWidget);
      await tester.tap(find.text('Still learning'));
      await tester.pump(const Duration(milliseconds: 300));

      for (final word in [words[1], words[2], words[0]]) {
        expect(find.text(word.tibetan), findsOneWidget);
        await tester.tap(find.text('Show meaning'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('I knew it'));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(result!.correct, 2);
      expect(result!.total, 3);
    });
  });

  group('GameHost', () {
    const topics = [
      GameTopic(id: 'fruits', name: 'Fruits', wordCount: 10, hasImages: true),
      GameTopic(id: 'tiny', name: 'Tiny', wordCount: 2, hasImages: true),
      GameTopic(id: 'plain', name: 'Plain', wordCount: 10, hasImages: false),
      GameTopic(id: 'empty', name: 'Hollow', wordCount: 10, hasImages: true),
    ];

    Widget host({bool needsImages = false}) => GameHost(
      title: 'Test Game',
      tagline: 'A game for tests.',
      gameId: 'test_game',
      needsImages: needsImages,
      repository: FakeRepository(
        topics: topics,
        words: {'fruits': tenWords, 'plain': tenWords},
      ),
      builder:
          (context, round) => Center(
            child: ElevatedButton(
              onPressed:
                  () => round.onFinished(
                    const GameResult(correct: 3, total: 4),
                  ),
              child: Text('Finish ${round.words.length} ${round.topicName}'),
            ),
          ),
    );

    testWidgets('offers only topics the game can use', (tester) async {
      await pumpGame(tester, host(needsImages: true));
      expect(find.text('Fruits'), findsOneWidget);
      expect(find.text('Hollow'), findsOneWidget);
      expect(find.text('Tiny'), findsNothing, reason: 'too few words');
      expect(find.text('Plain'), findsNothing, reason: 'no pictures');
    });

    testWidgets('runs a round, awards XP and remembers the best score', (
      tester,
    ) async {
      await pumpGame(tester, host());
      final xpBefore = progress.xp;

      await tester.tap(find.text('Fruits'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Finish 10 Fruits'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('New best score!'), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('+30'), findsOneWidget);
      expect(progress.xp, xpBefore + 30);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('game_best_test_game'), 3);

      // The day's first practice opens the streak celebration on top.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your streak has started!'), findsOneWidget);
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pump(const Duration(milliseconds: 400));

      // Matching the best again is not a new best.
      await tester.tap(find.text('Play again'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Finish 10 Fruits'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('New best score!'), findsNothing);
      expect(find.text('🏆 Best: 3 correct'), findsOneWidget);
    });

    testWidgets('a topic with no usable words returns to the picker', (
      tester,
    ) async {
      await pumpGame(tester, host());
      await tester.tap(find.text('Hollow'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('Could not load words. Check your connection.'),
        findsOneWidget,
      );
      expect(find.text('Pick a topic'), findsOneWidget);
    });
  });

  testWidgets('the Games tab lists all eight games', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpGame(tester, const ExtraGamesScreen());
    for (final title in const [
      'Listen & Tap',
      'Picture Pick',
      'Match Pairs',
      'True or False',
      'Word Builder',
      'Flashcards',
      'Memory Match',
      'Speed Quiz',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.textContaining('8 games'), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Spelling'), findsOneWidget);
  });

  testWidgets('the games kill switch hides the Games tab content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpGame(tester, const ExtraGamesScreen(enabled: false));
    expect(find.text('Games are taking a break'), findsOneWidget);
    expect(find.text('Listen & Tap'), findsNothing);
    expect(find.text('Games'), findsOneWidget);
  });

  testWidgets('the lesson style sheet saves the choice for every topic', (
    tester,
  ) async {
    await pumpGame(
      tester,
      Builder(
        builder:
            (context) => TextButton(
              onPressed: () => showLessonStylePicker(context),
              child: const Text('open'),
            ),
      ),
    );
    expect(theme.lessonStyle, LessonStyle.mixed);

    await tester.tap(find.text('open'));
    await tester.pump(); // starts the sheet's slide-in
    await tester.pump(const Duration(milliseconds: 400));
    for (final style in LessonStyle.values) {
      expect(find.text(style.title), findsOneWidget);
    }
    await tester.tap(find.text('Listening'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(theme.lessonStyle, LessonStyle.listening);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lesson_style'), 'listening');
  });
}
