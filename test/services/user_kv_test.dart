import 'dart:convert';

import 'package:bojang/services/user_kv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for /v1/kv with the server's version rules.
class FakeKvServer {
  final Map<String, Map<String, ({Object? value, int version})>> data = {};
  final List<Map<String, Object?>> patches = [];
  bool offline = false;

  Map<String, Object?> _items(String ns, [Set<String>? only]) => {
    for (final e in (data[ns] ?? {}).entries)
      if (only == null || only.contains(e.key))
        e.key: {'value': e.value.value, 'version': e.value.version},
  };

  Future<http.Response?> call(
    String method,
    String endpoint, {
    Object? body,
  }) async {
    if (offline) return null;
    final ns = endpoint.split('/').last;
    if (method == 'GET') {
      return http.Response(
        jsonEncode({'namespace': ns, 'items': _items(ns)}),
        200,
      );
    }
    final items = (body as Map)['items'] as List;
    patches.add(Map<String, Object?>.from(body));
    final store = data.putIfAbsent(ns, () => {});
    final conflicts = <String>[
      for (final item in items)
        if ((store[item['key']]?.version ?? 0) != item['version'])
          item['key'] as String,
    ];
    if (conflicts.isNotEmpty) {
      return http.Response(
        jsonEncode({
          'detail': {
            'error': 'version_conflict',
            'conflicts': conflicts,
            'current': _items(ns, conflicts.toSet()),
          },
        }),
        409,
      );
    }
    for (final item in items) {
      final key = item['key'] as String;
      if (item['delete'] == true) {
        store.remove(key);
      } else {
        store[key] = (
          value: item['value'],
          version: (store[key]?.version ?? 0) + 1,
        );
      }
    }
    return http.Response(
      jsonEncode({'namespace': ns, 'items': _items(ns)}),
      200,
    );
  }
}

void main() {
  late FakeKvServer server;
  late UserKv kv;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = FakeKvServer();
    kv = UserKv(transport: server.call, uid: () => 'uid-1');
  });

  test('update creates a key with version 0, then bumps it', () async {
    final first = await kv.update(
      'onboarding',
      'motivation',
      (_) => 'heritage',
    );
    expect(first?.value, 'heritage');
    expect(first?.version, 1);
    expect(server.patches.single['items'], [
      {'key': 'motivation', 'value': 'heritage', 'version': 0},
    ]);

    final second = await kv.update('onboarding', 'motivation', (_) => 'dharma');
    expect(second?.version, 2);
  });

  test(
    'a stale local copy is fixed by one retry on the server value',
    () async {
      // Another device wrote twice; this device has never read the key.
      server.data['features'] = {'chest_opened': (value: 4, version: 2)};

      final result = await kv.update(
        'features',
        'chest_opened',
        (current) => ((current as int?) ?? 0) + 1,
      );
      expect(result?.value, 5);
      expect(result?.version, 3);
      expect(server.patches, hasLength(2));
      expect((server.patches.last['items'] as List).single['version'], 2);
    },
  );

  test('a conflict on write reports the server state', () async {
    server.data['tips'] = {'games_tab': (value: 'x', version: 3)};
    final result = await kv.write('tips', [
      const KvWrite.set('games_tab', 'y', version: 1),
    ]);
    expect(result.outcome, KvOutcome.conflict);
    expect(result.conflicts, ['games_tab']);
    expect(result.entries['games_tab']?.version, 3);
    // The local copy now holds the server's version.
    expect((await kv.cached('tips'))['games_tab']?.version, 3);
  });

  test('offline: reads fall back to the local copy, writes fail', () async {
    await kv.update('onboarding', 'goal', (_) => 10);
    server.offline = true;
    expect((await kv.read('onboarding'))['goal']?.value, 10);
    expect(await kv.update('onboarding', 'goal', (_) => 20), isNull);
  });

  test('local copies are kept per account', () async {
    await kv.update('onboarding', 'goal', (_) => 10);
    final other = UserKv(transport: server.call, uid: () => 'uid-2');
    expect(await other.cached('onboarding'), isEmpty);
  });

  test('SeenTips marks once and reads locally', () async {
    final tips = SeenTips(kv);
    expect(await tips.hasSeen('streak_freeze'), isFalse);
    expect(await tips.markSeen('streak_freeze'), isTrue);
    expect(await tips.hasSeen('streak_freeze'), isTrue);
    expect(await tips.markSeen('streak_freeze'), isTrue);
    expect(server.patches, hasLength(1));
  });

  test('OnboardingAnswers and FeatureState round-trip', () async {
    final answers = OnboardingAnswers(kv);
    await answers.save('motivation', 'buddhist_study');
    await answers.save('prior_knowledge', 'can_read');
    expect(await answers.load(), {
      'motivation': 'buddhist_study',
      'prior_knowledge': 'can_read',
    });

    final features = FeatureState(kv);
    expect(await features.update('earn_back', (_) => {'sessions': 1}), {
      'sessions': 1,
    });
    expect(await features.get('earn_back'), {'sessions': 1});
    // Returning null deletes the key.
    expect(await features.update('earn_back', (_) => null), isNull);
    expect(await features.get('earn_back'), isNull);
  });
}
