import 'package:bojang/models/server_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isBelowMinimumBuild', () {
    test('blocks a build older than the minimum', () {
      expect(ServerConfig.isBelowMinimumBuild('62', 63), isTrue);
      expect(ServerConfig.isBelowMinimumBuild('9', 10), isTrue);
    });

    test('lets the minimum itself and newer builds in', () {
      expect(ServerConfig.isBelowMinimumBuild('63', 63), isFalse);
      expect(ServerConfig.isBelowMinimumBuild('64', 63), isFalse);
      // Numbers, not text: "100" is newer than "99".
      expect(ServerConfig.isBelowMinimumBuild('100', 99), isFalse);
    });

    test('fails open without a usable minimum or build number', () {
      expect(ServerConfig.isBelowMinimumBuild('1', null), isFalse);
      expect(ServerConfig.isBelowMinimumBuild('1', 0), isFalse);
      expect(ServerConfig.isBelowMinimumBuild('', 63), isFalse);
      expect(ServerConfig.isBelowMinimumBuild('2.14.0', 63), isFalse);
      expect(ServerConfig.isBelowMinimumBuild('abc', 63), isFalse);
    });

    test('tolerates spaces around the build number', () {
      expect(ServerConfig.parseBuildNumber(' 22 '), 22);
      expect(ServerConfig.isBelowMinimumBuild(' 22', 23), isTrue);
    });
  });

  group('requiresUpdate', () {
    final config = ServerConfig.fromJson({
      'min_supported_build': {'ios': 63, 'android': 30},
    });

    test('uses the minimum of the platform asked about', () {
      expect(
        config.requiresUpdate(platform: 'ios', installedBuild: '62'),
        isTrue,
      );
      expect(
        config.requiresUpdate(platform: 'ios', installedBuild: '63'),
        isFalse,
      );
      expect(
        config.requiresUpdate(platform: 'android', installedBuild: '29'),
        isTrue,
      );
      expect(
        config.requiresUpdate(platform: 'android', installedBuild: '62'),
        isFalse,
      );
    });

    test('never blocks an unknown platform', () {
      expect(
        config.requiresUpdate(platform: null, installedBuild: '1'),
        isFalse,
      );
      expect(
        config.requiresUpdate(platform: 'web', installedBuild: '1'),
        isFalse,
      );
    });

    test('the fail-open config never blocks', () {
      expect(
        ServerConfig.failOpen.requiresUpdate(
          platform: 'ios',
          installedBuild: '1',
        ),
        isFalse,
      );
    });
  });

  group('fromJson', () {
    test('reads the full /v1/config payload', () {
      final config = ServerConfig.fromJson({
        'schema_version': 1,
        'min_supported_build': {'ios': 0, 'android': 30},
        'update': {
          'title': 'Please update',
          'message': '  ',
          'store_url': {
            'ios': 'https://apps.apple.com/app/id6752509504',
            'android': 'http://insecure.example',
          },
        },
        'kill_switches': {'games': true, 'leaderboard': false},
        'analytics': {
          'blocklist': ['scroll', 7],
          'sampling': {'tap': 0.25, 'swipe': 3},
        },
        'flags': {
          'double_xp_weekend': true,
          'goal': 20,
          'bad': [1],
        },
        'rewards': {'xp_per_correct_answer': 10},
      });
      expect(config.minSupportedBuild, {'android': 30});
      expect(config.updateTitle, 'Please update');
      expect(config.updateMessage, isNull);
      expect(config.storeUrls, {
        'ios': 'https://apps.apple.com/app/id6752509504',
      });
      expect(config.isEnabled('games'), isFalse);
      expect(config.isEnabled('leaderboard'), isTrue);
      expect(config.isEnabled('never_heard_of_it'), isTrue);
      expect(config.eventBlocklist, {'scroll'});
      expect(config.eventSampling, {'tap': 0.25, 'swipe': 1.0});
      expect(config.flagBool('double_xp_weekend'), isTrue);
      expect(config.flagNum('goal'), 20);
      expect(config.flags.containsKey('bad'), isFalse);
      expect(config.flagString('missing', fallback: 'x'), 'x');
      expect(config.rewards['xp_per_correct_answer'], 10);
    });

    test('a malformed payload falls back to fail-open values', () {
      final config = ServerConfig.fromJson({
        'min_supported_build': 'lots',
        'kill_switches': ['games'],
        'analytics': null,
      });
      expect(config.minSupportedBuild, isEmpty);
      expect(config.isEnabled('games'), isTrue);
      expect(config.eventBlocklist, isEmpty);
    });
  });
}
