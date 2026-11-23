import 'dart:convert';

import 'package:bojang/models/social.dart';
import 'package:bojang/services/api_service.dart';
import 'package:bojang/services/social_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi implements ApiService {
  Map<String, dynamic>? lastWeek;
  Map<String, dynamic>? weekly;
  bool visibleOk = true;
  (int?, Object?) acceptResult = (200, {'link_id': 'l1'});
  (int?, Object?) nudgeResult = (200, {'sent': true});
  String? acceptedCode;

  @override
  Future<Map<String, dynamic>?> getLastWeekResult() async => lastWeek;
  @override
  Future<Map<String, dynamic>?> getWeeklyLeaderboard() async => weekly;
  @override
  Future<bool> setLeaderboardVisible(bool visible) async => visibleOk;
  @override
  Future<(int?, Object?)> acceptFamilyInvite(String code) async {
    acceptedCode = code;
    return acceptResult;
  }

  @override
  Future<(int?, Object?)> nudgeFamilyMember(String linkId) async => nudgeResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('last week result shows once', () async {
    final api = _FakeApi()
      ..lastWeek = {
        'week_start': '2026-11-16T00:00:00Z',
        'rank': 12,
        'xp': 140,
        'total_learners': 30,
      };
    final service = SocialService(api: api);
    final first = await service.unseenLastWeekResult();
    expect(first?.rank, 12);
    expect(await service.unseenLastWeekResult(), isNull);
  });

  test('visibility is remembered only when the server took it', () async {
    final api = _FakeApi();
    final service = SocialService(api: api);
    expect(await service.visible(), isTrue);
    expect(await service.setVisible(false), isTrue);
    expect(await service.visible(), isFalse);
    api.visibleOk = false;
    expect(await service.setVisible(true), isFalse);
    expect(await service.visible(), isFalse);
  });

  test('weekly board stores the server visibility', () async {
    final api = _FakeApi()
      ..weekly = jsonDecode(
        '{"week_start":"2026-11-23T00:00:00Z","week_end":"2026-11-30T00:00:00Z",'
        '"entries":[],"me":{"rank":null,"xp":0,"visible":false,"in_top":false,'
        '"display_name":"Learner 0001"},"total_learners":0}',
      ) as Map<String, dynamic>;
    final service = SocialService(api: api);
    expect((await service.weeklyBoard())!.me.visible, isFalse);
    expect(await service.visible(), isFalse);
  });

  test('accepting a code normalizes it and maps errors', () async {
    final api = _FakeApi();
    final service = SocialService(api: api);
    expect(await service.acceptInvite('k7qh-m2xp'), isNull);
    expect(api.acceptedCode, 'K7QHM2XP');
    expect(await service.acceptInvite('nope'), InviteError.invalid);
    api.acceptResult = (409, {'detail': {'error': 'family_full'}});
    expect(await service.acceptInvite('K7QHM2XP'), InviteError.full);
    api.acceptResult = (null, null);
    expect(await service.acceptInvite('K7QHM2XP'), InviteError.offline);
  });

  test('nudge outcomes', () async {
    final api = _FakeApi();
    final service = SocialService(api: api);
    expect(await service.nudge('l1'), NudgeOutcome.sent);
    api.nudgeResult = (429, null);
    expect(await service.nudge('l1'), NudgeOutcome.alreadyNudged);
    api.nudgeResult = (409, null);
    expect(await service.nudge('l1'), NudgeOutcome.alreadyPractised);
    api.nudgeResult = (null, null);
    expect(await service.nudge('l1'), NudgeOutcome.offline);
  });

  test('invite message carries the code and no personal data', () {
    final text = familyInviteMessage('K7QH-M2XP');
    expect(text, contains('K7QH-M2XP'));
    expect(text, contains('bojang.in'));
  });
}
