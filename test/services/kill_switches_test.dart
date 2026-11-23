import 'dart:convert';

import 'package:bojang/screens/dialogue_player_screen.dart';
import 'package:bojang/screens/extra_games_screen.dart';
import 'package:bojang/services/feature_flags.dart';
import 'package:bojang/services/offline_mode.dart';
import 'package:bojang/services/onboarding_service.dart';
import 'package:bojang/services/social_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every wave 2 feature reads its `/v1/config` kill switch through
/// [FeatureFlags], so the server can switch it off without a release.
void main() {
  const switches = [
    'onboarding',
    'leaderboard',
    'family',
    'dialogues',
    'offline_mode',
    'games',
  ];

  Future<void> applyKillSwitches(bool off) async {
    SharedPreferences.setMockInitialValues({
      FeatureFlags.cacheKey: jsonEncode({
        'etag': '"test"',
        'config': {
          'schema_version': 1,
          'kill_switches': {for (final name in switches) name: off},
        },
      }),
    });
    FeatureFlags.instance.debugReset();
    await FeatureFlags.instance.latest(wait: Duration.zero);
  }

  tearDown(() => FeatureFlags.instance.debugReset());

  test('each feature names its switch', () {
    expect(OnboardingService.killSwitch, 'onboarding');
    expect(DialoguePlayerScreen.killSwitch, 'dialogues');
    expect(OfflineMode.killSwitch, 'offline_mode');
    expect(ExtraGamesScreen.killSwitch, 'games');
  });

  test('switched off on the server, every feature is off', () async {
    await applyKillSwitches(true);
    for (final name in switches) {
      expect(FeatureFlags.instance.isEnabled(name), isFalse, reason: name);
    }
    expect(OnboardingService().enabled, isFalse);
    expect(SocialService.leaderboardEnabled, isFalse);
    expect(SocialService.familyEnabled, isFalse);
    expect(OfflineMode.instance.enabled, isFalse);

    await applyKillSwitches(false);
    expect(OnboardingService().enabled, isTrue);
    expect(SocialService.leaderboardEnabled, isTrue);
    expect(SocialService.familyEnabled, isTrue);
  });

  testWidgets('the games switch empties the Games tab', (tester) async {
    await tester.runAsync(() => applyKillSwitches(true));
    await tester.pumpWidget(const MaterialApp(home: ExtraGamesScreen()));
    await tester.pump();
    expect(find.text('Games are taking a break'), findsOneWidget);
    expect(find.text('Listen & Tap'), findsNothing);
  });
}
