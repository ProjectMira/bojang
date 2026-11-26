import 'dart:convert';

import 'package:bojang/models/level_models.dart';
import 'package:bojang/models/onboarding.dart';
import 'package:bojang/screens/onboarding_screen.dart';
import 'package:bojang/services/notification_primer.dart';
import 'package:bojang/services/onboarding_service.dart';
import 'package:bojang/services/user_kv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// user_kv namespace `onboarding` held in memory.
class _Kv {
  final Map<String, Object?> stored = {};
  bool offline = false;

  Future<http.Response?> call(
    String method,
    String endpoint, {
    Object? body,
  }) async {
    if (offline) return null;
    if (method == 'PATCH') {
      for (final item in (body as Map)['items'] as List) {
        stored[item['key'] as String] = item['value'];
      }
    }
    return http.Response(
      jsonEncode({
        'items': {
          for (final e in stored.entries)
            e.key: {'value': e.value, 'version': 1},
        },
      }),
      200,
    );
  }
}

List<Level> _levels() {
  Sublevel sub(String id, int order) =>
      Sublevel(level: '$order', name: id, path: 'api://level/$id');
  return [
    Level(
      level: 1,
      title: 'Tibetan Basics',
      sublevels: [sub('basics-letters-1', 1), sub('basics-numbers', 12)],
    ),
    Level(level: 2, title: 'Vocabulary', sublevels: [sub('vocab-action', 1)]),
  ];
}

void main() {
  late _Kv kv;
  late List<String> permissionRequests;
  late OnboardingResult? result;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    kv = _Kv();
    permissionRequests = [];
    result = null;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool canPrompt = true,
    bool dark = false,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: OnboardingScreen(
            service: OnboardingService(
              answers: OnboardingAnswers(
                UserKv(transport: kv.call, uid: () => 'u'),
              ),
              enabled: () => true,
            ),
            primer: NotificationPrimer(
              canPrompt: () async => canPrompt,
              requestPermission: (source) async {
                permissionRequests.add(source);
                return true;
              },
            ),
            loadLevels: () async => _levels(),
            onFinished: (r) => result = r,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('one tap per screen, Back keeps going, ends placed', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('Tashi delek'), findsOneWidget);
    await tap(tester, 'onboarding_start');

    expect(find.text('Why are you learning Tibetan?'), findsOneWidget);
    await tap(tester, 'motivation_buddhist');
    expect(find.text('How much Tibetan do you know?'), findsOneWidget);

    // Back returns one step with the answer kept.
    await tap(tester, 'onboarding_back');
    expect(find.text('Why are you learning Tibetan?'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tap(tester, 'motivation_buddhist');

    await tap(tester, 'knowledge_can_read');
    expect(find.text('Which Tibetan do you want to hear?'), findsOneWidget);
    // Every dialect offered can be picked: no dead "coming soon" choice.
    expect(find.textContaining('coming soon'), findsNothing);
    expect(find.byKey(const ValueKey('voice_amdo_male')), findsOneWidget);
    await tap(tester, 'voice_kham_male');

    await tap(tester, 'goal_2');
    expect(find.text('Maybe later'), findsOneWidget);
    await tap(tester, 'onboarding_notify_later');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.skipped, isFalse);
    expect(result!.startLevelId, 'basics-numbers');
    expect(result!.startLevel?.levelId, 'basics-numbers');
    expect(permissionRequests, isEmpty);
    expect(kv.stored, containsPair('motivation', 'buddhist'));
    expect(kv.stored, containsPair('prior_knowledge', 'can_read'));
    expect(kv.stored, containsPair('voice', 'kham_male'));
    expect(kv.stored, containsPair('daily_goal', 2));
    expect(kv.stored, containsPair('notifications', 'maybe_later'));
    expect(
      kv.stored,
      containsPair(OnboardingKeys.startLevel, 'basics-numbers'),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(OnboardingService.statusKey), 'done');
  });

  testWidgets('Skip leaves at once with what was answered', (tester) async {
    await pump(tester);
    await tap(tester, 'onboarding_start');
    await tap(tester, 'motivation_heritage');
    await tap(tester, 'onboarding_skip');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(result!.skipped, isTrue);
    expect(result!.startLevelId, Placement.basicsStart);
    expect(kv.stored['outcome'], 'skipped');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(OnboardingService.statusKey), 'skipped');
  });

  testWidgets('the primer step is left out when the OS cannot ask', (
    tester,
  ) async {
    await pump(tester, canPrompt: false);
    await tap(tester, 'onboarding_start');
    await tap(tester, 'motivation_travel');
    await tap(tester, 'knowledge_speak_some');
    await tap(tester, 'voice_lhasa_female');
    await tap(tester, 'goal_1');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Maybe later'), findsNothing);
    expect(result!.startLevelId, 'vocab-action');
  });

  testWidgets('turning reminders on asks the OS once, outside the primer cap', (
    tester,
  ) async {
    await pump(tester);
    for (final key in [
      'onboarding_start',
      'motivation_curious',
      'knowledge_none',
      'voice_lhasa_female',
      'goal_5',
      'onboarding_notify_on',
    ]) {
      await tap(tester, key);
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(permissionRequests, ['onboarding']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(NotificationPrimer.asksKey), isNull);
    expect(result!.startLevelId, 'basics-letters-1');
  });

  testWidgets('offline answers wait on the device for the next launch', (
    tester,
  ) async {
    kv.offline = true;
    await pump(tester);
    await tap(tester, 'onboarding_start');
    await tap(tester, 'motivation_buddhist');
    await tap(tester, 'onboarding_skip');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(kv.stored, isEmpty);
    kv.offline = false;
    final service = OnboardingService(
      answers: OnboardingAnswers(UserKv(transport: kv.call, uid: () => 'u')),
      enabled: () => true,
    );
    expect(await service.syncPending(), isTrue);
    expect(kv.stored['motivation'], 'buddhist');
    expect(await service.startLevelId(), Placement.basicsStart);
  });

  for (final dark in [false, true]) {
    for (final size in const [Size(390, 844), Size(1024, 1366)]) {
      testWidgets('lays out without overflow (dark: $dark, $size)', (
        tester,
      ) async {
        await pump(tester, dark: dark, size: size);
        expect(tester.takeException(), isNull);
        for (final key in [
          'onboarding_start',
          'motivation_travel',
          'knowledge_none',
        ]) {
          await tap(tester, key);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
