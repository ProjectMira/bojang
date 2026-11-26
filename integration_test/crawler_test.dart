// Crawler: visits every main screen and taps every enabled tappable the
// semantics tree exposes (see support/crawler.dart). Fails on exceptions and
// layout overflows; prints a coverage table (REPORT: lines, collected into
// report.md by ci/scripts/e2e.sh).
//
// The learner is an existing one (onboarding done, a few lessons, not a
// beginner), so every tab shows its full content.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/crawler.dart';
import 'support/harness.dart';

/// Links that leave the app (Safari / App Store) are not crawled.
const externalLinks = {
  'ta4tsering',
  'Full policy',
  'bojang.in',
  'Share Bojang',
  'Rate App',
};

/// The four tab buttons are driven by the crawler itself.
const tabLabels = {'Home tab', 'Practice tab', 'Games tab', 'Profile tab'};

Future<void> seedExistingLearner(SharedPreferences prefs) async {
  final now = DateTime.now();
  await prefs.setString('onboarding_status', 'done');
  await prefs.setInt('lessons_completed', 6);
  await prefs.setInt('xp', 420);
  await prefs.setInt('total_quizzes', 6);
  await prefs.setInt('total_correct', 50);
  await prefs.setInt('current_streak', 2);
  await prefs.setString('last_play_date', now.toIso8601String());
  // Don't let the name sheet open by itself on Profile.
  await prefs.setInt('learner_profile_asked_at', now.millisecondsSinceEpoch);
  await prefs.setString('animation_preference', 'off');
  await prefs.setBool('sound_effects_enabled', false);
}

void main() {
  initBinding();

  testWidgets('crawl every screen', (tester) async {
    // The coverage table, even when a screen fails part-way.
    addTearDown(printCrawlReport);
    await launchApp(tester, seed: seedExistingLearner);
    // share_plus opens a native sheet over the app.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async => 'dev.fluttercommunity.plus/share/unavailable',
    );
    await waitFor(tester, find.text('Practice'), timeout: 30, reason: 'main tabs');
    await wait(tester, 4);
    await grantXp(3); // a row on this week's board

    Future<void> tab(String name) async {
      await tapIt(tester, find.text(name).last, settle: 2.5);
    }

    final skip = {...externalLinks, ...tabLabels};

    for (final name in ['Home', 'Practice', 'Games', 'Profile']) {
      await tab(name);
      await shot('crawl-tab-$name');
      await crawlScreen(tester, name, skip: skip, restore: () => tab(name));
    }

    // Screens pushed from the tabs.
    Future<void> crawlPushed(
      String name,
      Future<void> Function() open, {
      int maxTaps = 45,
    }) async {
      await tab('Profile');
      await open();
      await wait(tester, 2.5);
      await shot('crawl-screen-$name');
      await crawlScreen(tester, name, skip: skip, maxTaps: maxTaps);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.popUntil((r) => r.isFirst);
      await wait(tester, 1);
    }

    await crawlPushed('Settings', () => tapIt(tester, find.byIcon(Icons.settings).first));
    await crawlPushed('Notification settings', () async {
      await tapIt(tester, find.byIcon(Icons.settings).first, settle: 1.5);
      await scrollTo(tester, find.text('Notifications'));
      await tapText(tester, 'Notifications');
    });
    await crawlPushed(
      'Leaderboard',
      () => tapIt(tester, find.byKey(const Key('profile-board-card'))),
      maxTaps: 25,
    );
    await crawlPushed('All topics', () async {
      await tab('Home');
      await scrollTo(tester, find.text('Browse all topics'));
      await tapText(tester, 'Browse all topics');
    }, maxTaps: 30);
    await crawlPushed('Streak', () async {
      await tab('Home');
      final semantics = tester.ensureSemantics();
      await tapIt(tester, find.bySemanticsLabel(RegExp('day streak')));
      semantics.dispose();
      final details = find.text('Streak details');
      if (details.evaluate().isNotEmpty) await tapIt(tester, details);
    }, maxTaps: 25);

    final errors = [
      for (final r in crawlReports)
        for (final t in r.taps.where((t) => t.outcome == 'error')) '${r.screen}: ${t.label}: ${t.detail}',
    ];
    expect(errors, isEmpty, reason: 'taps that threw or overflowed');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
