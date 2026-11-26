// Helpers for the Games tab journeys (journeys_games_test.dart).

import 'package:bojang/models/game_word.dart';
import 'package:bojang/screens/extra_games_screen.dart';
import 'package:bojang/screens/games/game_widgets.dart';
import 'package:bojang/screens/streak_celebration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

/// Prefs for a learner who has been through onboarding (so the app opens on
/// Home) with animations and sound effects off for steadier timing.
Future<void> seedReturningLearner(SharedPreferences prefs) async {
  await prefs.setString('onboarding_status', 'done');
  await prefs.setString('animation_preference', 'off');
  await prefs.setBool('sound_effects_enabled', false);
}

/// Waits for the main navigation and switches to [tab].
Future<void> openTab(WidgetTester tester, String tab) async {
  await waitFor(
    tester,
    find.text(tab).hitTestable(),
    timeout: 30,
    reason: '$tab tab',
  );
  await tapText(tester, tab, settle: 1);
}

/// Opens [title] from the Games tab: the signboard's Play button when it is
/// today's game, otherwise its shelf row. Retries a tap that landed while
/// the tab was still switching.
Future<void> openGame(WidgetTester tester, String title) async {
  await openTab(tester, 'Games');
  await waitFor(tester, find.textContaining('8 games'), reason: 'Games header');
  await wait(tester, 1);
  final opened = [
    find.text('Pick a topic'),
    find.text('Quick-fire round'),
    find.text('Finding topics to play…'),
    find.text('Shuffling the cards…'),
    find.text('Retry'),
    find.text('Play with the Alphabet'),
  ];
  final featured = ExtraGamesScreen.featuredTitle(DateTime.now()) == title;
  final target =
      featured
          ? find.byKey(const ValueKey('featured_game_play'))
          : find.text(title);
  for (var attempt = 0; attempt < 2; attempt++) {
    await waitFor(tester, target, reason: 'game $title');
    await tester.ensureVisible(target.first);
    await wait(tester, 0.6);
    await tester.tap(target.first, warnIfMissed: false);
    if (await waitForAny(tester, opened, timeout: 4) >= 0) return;
  }
  if (featured) {
    // flutter_test's synthetic taps don't reach the signboard's Play button
    // (the hit test lands on its InkWell, but onTap never fires); a real
    // touch on the simulator opens the game. Fire the button's own onTap.
    debugPrint('NOTE: synthetic tap missed featured Play; invoking onTap');
    tester.widget<InkWell>(target.first).onTap!.call();
    if (await waitForAny(tester, opened, timeout: 6) >= 0) return;
  }
  await shot('open-game-failed-${title.replaceAll(RegExp('[^A-Za-z]'), '')}');
  fail('Tapping "$title" did not open the game');
}

/// Opens the weekly leaderboard from the Games header trophy (the same
/// synthetic-tap gap as the featured Play button applies).
Future<void> openBoardFromGames(WidgetTester tester) async {
  final trophy = find.byTooltip('Weekly leaderboard');
  await tester.ensureVisible(trophy);
  await wait(tester, 0.6);
  await tester.tap(trophy, warnIfMissed: false);
  await wait(tester, 2);
  if (find.text('This week').evaluate().isEmpty &&
      find.text('The board is out of reach').evaluate().isEmpty) {
    debugPrint('NOTE: synthetic tap missed the trophy; invoking onPressed');
    final button = find.ancestor(of: trophy, matching: find.byType(IconButton));
    tester.widget<IconButton>(button.first).onPressed!.call();
    await wait(tester, 2);
  }
}

/// The topic picker of a GameHost game or Memory Match: taps [topic].
Future<void> pickTopic(WidgetTester tester, String topic) async {
  await waitFor(
    tester,
    find.text('Pick a topic'),
    timeout: 20,
    reason: 'topic picker',
  );
  final tile = find.text(topic);
  await waitFor(tester, tile, reason: 'topic $topic');
  await scrollTo(tester, tile.first);
  await tapIt(tester, tile, settle: 1.5);
}

/// The word a game is asking about: the first WordSpeaker on screen is the
/// target's in every GameHost game that has one.
/// Word Builder shows only the target's picture (WordImage) until solved.
GameWord targetWord(WidgetTester tester) {
  final speaker = find.byType(WordSpeaker);
  if (speaker.evaluate().isNotEmpty) {
    return tester.widget<WordSpeaker>(speaker.first).word;
  }
  return tester.widget<WordImage>(find.byType(WordImage).first).word;
}

int gameScore(WidgetTester tester) =>
    tester
        .widget<GameProgressHeader>(find.byType(GameProgressHeader).first)
        .score;

int gameStep(WidgetTester tester) =>
    tester
        .widget<GameProgressHeader>(find.byType(GameProgressHeader).first)
        .step;

/// Pops the current game route like the AppBar back chevron does.
Future<void> leaveGame(WidgetTester tester) async {
  final back = find.byTooltip('Back').hitTestable();
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.last, warnIfMissed: false);
  } else {
    final scopes = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('_ModalScope'),
    );
    await Navigator.of(scopes.evaluate().last).maybePop();
  }
  await wait(tester, 1.2);
}

/// Dismisses what can follow a finished game: the streak celebration and
/// the notification primer. Returns what it dismissed.
Future<List<String>> dismissInterstitials(
  WidgetTester tester, {
  double seconds = 6,
}) async {
  final dismissed = <String>[];
  final end = DateTime.now().add(
    Duration(milliseconds: (seconds * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    final primer = find.byKey(const ValueKey('notification_primer_not_now'));
    if (primer.hitTestable().evaluate().isNotEmpty) {
      await tapIt(tester, primer);
      dismissed.add('primer');
      continue;
    }
    if (find.byType(StreakCelebrationScreen).evaluate().isNotEmpty) {
      final inside = find.descendant(
        of: find.byType(StreakCelebrationScreen),
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'Not now' || w.data == 'Continue'),
        ),
      );
      if (inside.hitTestable().evaluate().isNotEmpty) {
        await tapIt(tester, inside, settle: 1);
        dismissed.add('streak');
        continue;
      }
    }
  }
  return dismissed;
}

// --- connectivity_plus (5.x) ----------------------------------------------

const _connectivity = 'dev.fluttercommunity.plus/connectivity';
const _connectivityStatus = 'dev.fluttercommunity.plus/connectivity_status';

/// Makes connectivity_plus report [online] (for `check` and as a change
/// event to the app's onConnectivityChanged listener).
Future<void> setConnectivity(bool online) async {
  final state = online ? 'wifi' : 'none';
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel(_connectivity),
    (call) async => call.method == 'check' ? state : null,
  );
  await binding.defaultBinaryMessenger.handlePlatformMessage(
    _connectivityStatus,
    const StandardMethodCodec().encodeSuccessEnvelope(state),
    (_) {},
  );
}

void clearConnectivityMock() => binding.defaultBinaryMessenger
    .setMockMethodCallHandler(const MethodChannel(_connectivity), null);
