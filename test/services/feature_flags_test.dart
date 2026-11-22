import 'dart:convert';

import 'package:bojang/services/analytics.dart';
import 'package:bojang/services/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _config({bool gamesOff = false, int android = 0}) => {
  'schema_version': 1,
  'min_supported_build': {'ios': 0, 'android': android},
  'kill_switches': {'games': gamesOff, 'leaderboard': false},
  'analytics': {
    'blocklist': ['scroll'],
    'sampling': <String, double>{},
  },
  'flags': <String, Object>{},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => FeatureFlags.instance.debugReset());

  test('fails open before anything is fetched or cached', () async {
    final flags = FeatureFlags(fetcher: (_) async => null);
    await flags.init();
    final config = await flags.latest();
    expect(config.isEnabled('games'), isTrue);
    expect(config.minSupportedBuild, isEmpty);
  });

  test('revalidates with the ETag and keeps the config on 304', () async {
    final seen = <Map<String, String>>[];
    var answer = http.Response(
      jsonEncode(_config(gamesOff: true)),
      200,
      headers: {'etag': '"v1"'},
    );
    var now = DateTime(2026, 11, 22, 10);
    final flags = FeatureFlags(
      fetcher: (headers) async {
        seen.add(headers);
        return answer;
      },
      clock: () => now,
    );
    await flags.init();
    await flags.latest();
    expect(seen.single, isEmpty);
    expect(flags.isEnabled('games'), isFalse);
    expect(flags.etag, '"v1"');

    // Within refreshAfter nothing is asked.
    await flags.refresh();
    expect(seen, hasLength(1));

    now = now.add(FeatureFlags.refreshAfter);
    answer = http.Response('', 304, headers: {'etag': '"v1"'});
    await flags.refresh();
    expect(seen.last, {'If-None-Match': '"v1"'});
    expect(flags.isEnabled('games'), isFalse);
  });

  test('the cached config applies on the next launch, even offline', () async {
    final first = FeatureFlags(
      fetcher:
          (_) async => http.Response(
            jsonEncode(_config(android: 30)),
            200,
            headers: {'etag': '"v2"'},
          ),
    );
    await first.init();
    await first.latest();

    final offline = FeatureFlags(fetcher: (_) async => null);
    await offline.init();
    final config = await offline.latest();
    expect(config.minSupportedBuild['android'], 30);
    expect(offline.etag, '"v2"');
  });

  test('errors and bad bodies keep the last good config', () async {
    var answer = http.Response(jsonEncode(_config(gamesOff: true)), 200);
    final flags = FeatureFlags(fetcher: (_) async => answer);
    await flags.init();
    await flags.latest();

    for (final bad in [
      http.Response('oops', 500),
      http.Response('not json', 200),
      http.Response('[1, 2]', 200),
    ]) {
      answer = bad;
      await flags.refresh(force: true);
      expect(flags.isEnabled('games'), isFalse);
    }
  });

  test('applies the analytics blocklist', () async {
    final flags = FeatureFlags(
      fetcher: (_) async => http.Response(jsonEncode(_config()), 200),
    );
    await flags.init();
    await flags.latest();
    expect(Analytics.allowsEvent('scroll'), isFalse);
    expect(Analytics.allowsEvent('tap'), isTrue);
  });
}
