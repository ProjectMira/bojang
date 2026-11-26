// Games tab journeys and offline mode, end to end (see TESTING.md).
//
//   ci/scripts/e2e.sh integration_test/journeys_games_test.dart
//
// Every game: open it, pick a topic, make a right move and check the score
// moved, then finish it or quit. Picture topics (Animals, Fruits, Colors,
// Family) have placeholder pictures and silent audio in the local backend.

import 'dart:math';

import 'package:bojang/screens/games/flashcards_game.dart';
import 'package:bojang/screens/games/match_pairs_game.dart';
import 'package:bojang/screens/games/picture_pick_game.dart';
import 'package:bojang/screens/games/true_false_game.dart';
import 'package:bojang/screens/games/word_builder_game.dart';
import 'package:bojang/screens/memory_match_game.dart';
import 'package:bojang/screens/speed_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/games.dart';
import 'support/harness.dart';

const topic = 'Animals';

void main() {
  initBinding();

  tearDown(() async {
    clearConnectivityMock();
    try {
      await setOutage(false);
    } catch (_) {}
  });

  testWidgets('Listen & Tap and Picture Pick: right picture scores', (
    tester,
  ) async {
    await launchApp(tester, seed: seedReturningLearner);
    for (final title in ['Listen & Tap', 'Picture Pick']) {
      await openGame(tester, title);
      await pickTopic(tester, topic);
      await waitFor(
        tester,
        find.byType(PicturePickGame),
        timeout: 20,
        reason: '$title board',
      );
      await wait(tester, 1);
      expect(gameScore(tester), 0);
      final target = targetWord(tester);
      final tile = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.endsWith('-${target.id}'),
      );
      expect(
        tile,
        findsOneWidget,
        reason: '$title: the target is one of the tiles',
      );
      await tapIt(tester, tile, settle: 0.4);
      expect(
        gameScore(tester),
        1,
        reason: '$title: right picture adds a point',
      );
      await shot(
        'games-${title.replaceAll(' ', '').replaceAll('&', '')}-right',
      );
      // Advances to the next word after 1.3 s.
      await waitFor(
        tester,
        find.textContaining('Word 2 of'),
        reason: '$title next word',
      );
      await leaveGame(tester); // back to the Games tab
      await waitFor(tester, find.text('Games'));
    }
  });

  testWidgets('Match Pairs: a right pair scores', (tester) async {
    await launchApp(tester, seed: seedReturningLearner);
    await openGame(tester, 'Match Pairs');
    await pickTopic(tester, topic);
    await waitFor(tester, find.byType(MatchPairsGame), timeout: 20);
    await wait(tester, 1);
    final left = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('left-'),
    );
    expect(left, findsWidgets);
    final id = (tester.widget(left.first).key! as ValueKey<String>).value
        .substring(5);
    await tapIt(tester, find.byKey(ValueKey('left-$id')), settle: 0.3);
    await tapIt(tester, find.byKey(ValueKey('right-$id')), settle: 0.6);
    expect(
      gameScore(tester),
      greaterThanOrEqualTo(1),
      reason: 'matched pair scores',
    );
    await shot('games-matchpairs-right');
    await leaveGame(tester);
  });

  testWidgets('True or False: answer from the meaning', (tester) async {
    await launchApp(tester, seed: seedReturningLearner);
    await openGame(tester, 'True or False');
    await pickTopic(tester, topic);
    await waitFor(tester, find.byType(TrueFalseGame), timeout: 20);
    await wait(tester, 1);
    final target = targetWord(tester);
    final claimTrue =
        find
            .descendant(
              of: find.byType(TrueFalseGame),
              matching: find.text(target.english),
            )
            .evaluate()
            .isNotEmpty;
    await tapText(tester, claimTrue ? 'True' : 'False', settle: 0.4);
    await waitFor(tester, find.text('Right!'), reason: 'right answer feedback');
    expect(gameScore(tester), 1);
    await shot('games-truefalse-right');
    await leaveGame(tester);
  });

  testWidgets('Word Builder: syllables in order', (tester) async {
    await launchApp(tester, seed: seedReturningLearner);
    await openGame(tester, 'Word Builder');
    await pickTopic(tester, topic);
    await waitFor(tester, find.byType(WordBuilderGame), timeout: 20);
    await wait(tester, 1);
    final word = targetWord(tester);
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('tile-0-'),
    );
    final texts = <int, String>{};
    for (final e in tiles.evaluate()) {
      final key = (e.widget.key! as ValueKey<String>).value;
      final t = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Text),
      );
      texts[int.parse(key.split('-').last)] =
          (tester.widget<Text>(t.first).data ?? '').trim();
    }
    final used = <int>{};
    for (final syllable in word.syllables) {
      final i =
          texts.entries
              .firstWhere(
                (e) => e.value == syllable && !used.contains(e.key),
                orElse:
                    () =>
                        throw TestFailure('no tile for "$syllable" in $texts'),
              )
              .key;
      used.add(i);
      await tapIt(tester, find.byKey(ValueKey('tile-0-$i')), settle: 0.3);
    }
    await wait(tester, 0.6);
    expect(gameScore(tester), 1, reason: 'built word scores');
    await shot('games-wordbuilder-right');
    await leaveGame(tester);
  });

  testWidgets('Flashcards: finish a round to the result screen', (
    tester,
  ) async {
    await launchApp(tester, seed: seedReturningLearner);
    await openGame(tester, 'Flashcards');
    await pickTopic(tester, topic);
    await waitFor(tester, find.byType(FlashcardsGame), timeout: 20);
    for (var i = 0; i < 25; i++) {
      if (find.byType(FlashcardsGame).evaluate().isEmpty) break;
      await tapText(tester, 'Show meaning', settle: 0.6);
      await tapText(tester, 'I knew it', settle: 0.8);
    }
    await dismissInterstitials(tester);
    await waitFor(
      tester,
      find.text('Play again'),
      timeout: 10,
      reason: 'result screen',
    );
    expect(find.text('Change topic'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    await shot('games-flashcards-result');
    await tapText(tester, 'Play again', settle: 1.5);
    await waitFor(
      tester,
      find.byType(FlashcardsGame),
      reason: 'Play again restarts',
    );
    // GameHost is one route: back leaves the game, picker included.
    await leaveGame(tester);
    await waitFor(
      tester,
      find.textContaining('8 games'),
      reason: 'back to Games',
    );
  });

  testWidgets('Memory Match: play to the result and use its buttons', (
    tester,
  ) async {
    await launchApp(tester, seed: seedReturningLearner);
    await openGame(tester, 'Memory Match');
    await pickTopic(tester, topic);
    final rnd = Random(7);
    final done = find.byKey(const ValueKey('memory_match_done'));

    Future<void> playToResult() async {
      await waitFor(
        tester,
        find.byIcon(Icons.help_outline),
        timeout: 20,
        reason: 'cards',
      );
      for (var move = 0; move < 80 && done.evaluate().isEmpty; move++) {
        final hidden = find.byIcon(Icons.help_outline).hitTestable();
        final n = hidden.evaluate().length;
        if (n < 2) {
          await wait(tester, 0.5);
          continue;
        }
        final a = rnd.nextInt(n);
        var b = rnd.nextInt(n - 1);
        if (b >= a) b++;
        // Flipping a card removes its icon, so take both centres first.
        final pa = tester.getCenter(hidden.at(a));
        final pb = tester.getCenter(hidden.at(b));
        await tester.tapAt(pa);
        await wait(tester, 0.15);
        await tester.tapAt(pb);
        await wait(tester, 1.5);
      }
      await waitFor(
        tester,
        done,
        timeout: 5,
        reason: 'Memory Match result dialog',
      );
    }

    await playToResult();
    expect(find.textContaining('Well done!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('memory_match_play_again')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memory_match_change_topic')),
      findsOneWidget,
    );
    await shot('games-memorymatch-result');

    await tapIt(
      tester,
      find.byKey(const ValueKey('memory_match_play_again')),
      settle: 1.5,
    );
    await playToResult(); // same topic again
    await tapIt(
      tester,
      find.byKey(const ValueKey('memory_match_change_topic')),
      settle: 1,
    );
    await waitFor(
      tester,
      find.text('Pick a topic'),
      reason: 'Change topic goes to the picker',
    );
    await pickTopic(tester, topic);
    await playToResult();
    await tapIt(tester, done, settle: 1.5);
    await waitGone(tester, find.byType(MemoryMatchGame));
    await waitFor(
      tester,
      find.text('Games'),
      reason: 'Done returns to the Games tab',
    );
  });

  testWidgets('Speed Quiz: start, score a right answer, quit', (tester) async {
    await launchApp(tester, seed: seedReturningLearner);
    await openGame(tester, 'Speed Quiz');
    await tapIt(tester, find.text('Start'), settle: 1);
    await waitFor(
      tester,
      find.text('Score: 0'),
      timeout: 20,
      reason: 'round started',
    );
    expect(find.textContaining(' s'), findsWidgets);
    final options = find.descendant(
      of: find.byType(SpeedQuizScreen),
      matching: find.ancestor(
        of: find.byType(Text),
        matching: find.byType(InkWell),
      ),
    );
    var scored = false;
    for (var i = 0; i < 12 && !scored; i++) {
      await waitFor(tester, options.hitTestable(), reason: 'options');
      await tester.tap(options.hitTestable().first, warnIfMissed: false);
      await wait(tester, 0.9);
      scored = find.text('Score: 0').evaluate().isEmpty;
    }
    expect(scored, isTrue, reason: 'a right answer raises the score');
    await shot('games-speedquiz-scored');
    await leaveGame(tester);
    await dismissInterstitials(tester, seconds: 3);
    await waitGone(tester, find.byType(SpeedQuizScreen));
  });

  testWidgets('Offline / no server: every screen says so and recovers', (
    tester,
  ) async {
    await launchApp(tester, seed: seedReturningLearner);
    await openTab(tester, 'Home');
    await wait(tester, 3);
    expect(myUid(), isNotNull);
    await setOutage(true);
    await setConnectivity(false);
    await wait(tester, 1.5);

    // Home banner.
    await waitFor(
      tester,
      find.text("You're offline"),
      reason: 'Home offline banner',
    );
    // Home auto-scrolls to the active path node, so the banner at the top
    // starts off-screen; bring it into view for the screenshot.
    await tester.ensureVisible(find.text("You're offline"));
    await wait(tester, 0.5);
    await shot('offline-home');

    // Practice.
    await openTab(tester, 'Practice');
    await waitFor(
      tester,
      find.text('Can’t reach Bojang'),
      timeout: 20,
      reason: 'Practice offline',
    );
    expect(find.text('Retry'), findsOneWidget);
    await shot('offline-practice');

    // A GameHost game.
    await openGame(tester, 'Match Pairs');
    await waitFor(
      tester,
      find.text('Retry'),
      timeout: 20,
      reason: 'GameHost offline notice',
    );
    expect(find.textContaining('lost the trail'), findsOneWidget);
    await shot('offline-matchpairs');

    // Recovery: the server comes back and Retry loads topics.
    await setOutage(false);
    await setConnectivity(true);
    await tapText(tester, 'Retry', settle: 2);
    await waitFor(
      tester,
      find.text('Pick a topic'),
      timeout: 20,
      reason: 'Retry recovers',
    );
    await leaveGame(tester);
    await setOutage(true);
    await setConnectivity(false);

    // Memory Match: the alphabet still plays.
    await openGame(tester, 'Memory Match');
    await waitFor(
      tester,
      find.text('Play with the Alphabet'),
      timeout: 20,
      reason: 'alphabet offer',
    );
    await shot('offline-memorymatch');
    await tapText(tester, 'Play with the Alphabet', settle: 1.5);
    await waitFor(
      tester,
      find.byIcon(Icons.help_outline),
      reason: 'alphabet cards',
    );
    final hidden = find.byIcon(Icons.help_outline).hitTestable();
    final p0 = tester.getCenter(hidden.at(0));
    final p1 = tester.getCenter(hidden.at(1));
    await tester.tapAt(p0);
    await wait(tester, 0.2);
    await tester.tapAt(p1);
    await wait(tester, 1.5);
    expect(find.text('1'), findsWidgets, reason: 'Moves counted');
    await leaveGame(tester);

    // Leaderboard (the trophy on the Games header).
    await waitFor(tester, find.text('Games'));
    await openBoardFromGames(tester);
    await waitFor(
      tester,
      find.text('The board is out of reach'),
      timeout: 20,
      reason: 'Leaderboard offline',
    );
    await shot('offline-leaderboard');
    await leaveGame(tester);

    await setOutage(false);
    await setConnectivity(true);
    await openTab(tester, 'Practice');
    // Practice reloads when shown; tap Retry only if the error is still up.
    await wait(tester, 2);
    if (find.text('Retry').hitTestable().evaluate().isNotEmpty) {
      await tapText(tester, 'Retry', settle: 2);
    }
    await waitGone(tester, find.text('Can’t reach Bojang'), timeout: 20);
    await shot('offline-recovered-practice');
  });
}
