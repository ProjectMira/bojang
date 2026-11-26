import 'package:bojang/screens/leaderboard_screen.dart';
import 'package:bojang/services/api_service.dart';
import 'package:bojang/services/learner_profile.dart';
import 'package:bojang/services/social_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi implements ApiService {
  _FakeApi(this.weekly);

  Map<String, dynamic> weekly;
  final hidden = <String>[];
  final reports = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>?> getWeeklyLeaderboard() async => weekly;
  @override
  Future<bool> hideLeaderboardEntry(String token) async {
    hidden.add(token);
    return true;
  }

  @override
  Future<int?> reportLeaderboardEntry({
    required String token,
    required String kind,
    required String reason,
    bool hide = false,
  }) async {
    reports.add({'token': token, 'kind': kind, 'reason': reason, 'hide': hide});
    return 200;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _board({required int myRank, int count = 50}) => {
  'week_start': '2026-11-23T00:00:00Z',
  'week_end': '2026-11-30T00:00:00Z',
  'entries': [
    for (var i = 1; i <= count; i++)
      {
        'rank': i,
        'display_name': i == myRank ? 'Tashi' : 'Learner $i',
        'xp': 1000 - i,
        'is_me': i == myRank,
        'avatar': 'conch:gold',
        'token': 'tok-$i',
      },
  ],
  'me': {
    'rank': myRank,
    'xp': myRank <= count ? 1000 - myRank : 12,
    'visible': true,
    'in_top': myRank <= count,
    'display_name': 'Tashi',
    'avatar': 'yak_love:red',
  },
  'total_learners': myRank <= count ? count : myRank,
};

Future<_FakeApi> _pump(WidgetTester tester, Map<String, dynamic> board) async {
  final api = _FakeApi(board);
  await tester.pumpWidget(
    MaterialApp(home: LeaderboardScreen(service: SocialService(api: api))),
  );
  await _settle(tester);
  return api;
}

/// The header yak animates forever, so pumpAndSettle never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _bar = find.byKey(const Key('board-my-rank-bar'));

void main() {
  setUp(() {
    // A learner with a name and picture is not asked to set them.
    SharedPreferences.setMockInitialValues({
      LearnerProfile.nameKey: 'Tashi',
      LearnerProfile.avatarKey: 'yak_love:red',
    });
    LearnerProfile.instance.debugReset();
    LearnerProfile.instance.fetch = () async => null;
  });

  testWidgets('my row near the top: "You" chip, no pinned bar', (tester) async {
    await _pump(tester, _board(myRank: 2));
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Tashi'), findsOneWidget);
    final bar = tester.widget<IgnorePointer>(
      find.ancestor(of: _bar, matching: find.byType(IgnorePointer)).first,
    );
    expect(bar.ignoring, isTrue);
  });

  testWidgets('outside the top 50: "Your rank" bar is pinned', (tester) async {
    await _pump(tester, _board(myRank: 73));
    expect(find.text('Your rank #73 · 12 XP'), findsOneWidget);
    final bar = tester.widget<IgnorePointer>(
      find.ancestor(of: _bar, matching: find.byType(IgnorePointer)).first,
    );
    expect(bar.ignoring, isFalse);
  });

  testWidgets('my row scrolled off screen pins the bar', (tester) async {
    await _pump(tester, _board(myRank: 45));
    final bar = find.ancestor(of: _bar, matching: find.byType(IgnorePointer));
    expect(tester.widget<IgnorePointer>(bar.first).ignoring, isFalse);
    await tester.tap(_bar);
    await _settle(tester);
    expect(find.text('You'), findsOneWidget);
    expect(tester.widget<IgnorePointer>(bar.first).ignoring, isTrue);
  });

  testWidgets('long-press another row to hide them', (tester) async {
    final api = await _pump(tester, _board(myRank: 2));
    await tester.longPress(find.text('Learner 1'));
    await _settle(tester);
    expect(find.text('Report name'), findsOneWidget);
    expect(find.text('Report photo'), findsNothing); // no photo
    await tester.tap(find.byKey(const Key('board-hide')));
    await _settle(tester);
    expect(api.hidden, ['tok-1']);
    expect(find.text('Learner 1'), findsNothing);
  });

  testWidgets('report a name with a reason, also hiding them', (tester) async {
    final api = await _pump(tester, _board(myRank: 2));
    await tester.tap(find.byTooltip('Report or hide').first);
    await _settle(tester);
    await tester.tap(find.byKey(const Key('board-report-name')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('board-reason-offensive')));
    await _settle(tester);
    expect(api.reports, [
      {'token': 'tok-1', 'kind': 'name', 'reason': 'offensive', 'hide': true},
    ]);
    expect(find.text('Learner 1'), findsNothing);
  });

  testWidgets('my own row has no report menu', (tester) async {
    await _pump(tester, _board(myRank: 1, count: 3));
    await tester.longPress(find.text('Tashi'));
    await _settle(tester);
    expect(find.text('Report name'), findsNothing);
    expect(find.byTooltip('Report or hide'), findsNWidgets(2));
  });

  testWidgets('a shown city is a second line and can be reported', (
    tester,
  ) async {
    final board = _board(myRank: 2, count: 3);
    (board['entries'] as List)[0]['place'] = 'Dharamsala, India';
    final api = await _pump(tester, board);
    expect(find.text('Dharamsala, India'), findsOneWidget);
    await tester.longPress(find.text('Learner 1'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('board-report-place')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('board-reason-spam')));
    await _settle(tester);
    expect(api.reports.single['kind'], 'place');
  });
}
