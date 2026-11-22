import 'dart:convert';
import 'dart:io';

import 'package:bojang/models/server_config.dart';
import 'package:bojang/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('compareVersions', () {
    test('orders by each numeric part, not as text', () {
      expect(AppUpdateService.compareVersions('2.10.0', '2.9.3'), 1);
      expect(AppUpdateService.compareVersions('2.6.1', '2.7.0'), -1);
      expect(AppUpdateService.compareVersions('3.0.0', '2.99.99'), 1);
    });

    test('treats missing parts as zero', () {
      expect(AppUpdateService.compareVersions('2.6', '2.6.0'), 0);
      expect(AppUpdateService.compareVersions('2.6', '2.6.1'), -1);
      expect(AppUpdateService.compareVersions('2.6.1', '2.6.1'), 0);
    });
  });

  test('parseOsVersion reads the number out of the iOS version string', () {
    expect(
      AppUpdateService.parseOsVersion('Version 17.2 (Build 21C62)'),
      '17.2',
    );
    expect(
      AppUpdateService.parseOsVersion('Version 18.4.1 (Build 22E252)'),
      '18.4.1',
    );
    expect(AppUpdateService.parseOsVersion('unknown'), isNull);
  });

  group('check', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    PackageInfo installed(String version) => PackageInfo(
      appName: 'Bojang',
      packageName: 'com.bojang.app',
      version: version,
      buildNumber: '1',
    );

    String lookup({String version = '2.7.0', String minOs = '15.0'}) =>
        jsonEncode({
          'resultCount': 1,
          'results': [
            {
              'trackId': 6752509504,
              'version': version,
              'minimumOsVersion': minOs,
              'bundleId': 'com.bojang.app',
            },
          ],
        });

    AppUpdateService service({
      required String installedVersion,
      http.Client? client,
      String os = 'Version 18.4 (Build 22E238)',
      bool isIOS = true,
    }) => AppUpdateService(
      client: client ?? MockClient((_) async => http.Response(lookup(), 200)),
      packageInfo: () async => installed(installedVersion),
      osVersion: () => os,
      isIOS: isIOS,
    );

    test('requires the update when the store has a newer version', () async {
      Uri? asked;
      final update =
          await service(
            installedVersion: '2.6.1',
            client: MockClient((request) async {
              asked = request.url;
              return http.Response(lookup(version: '2.7.0'), 200);
            }),
          ).check();

      expect(asked!.host, 'itunes.apple.com');
      expect(asked!.queryParameters['bundleId'], 'com.bojang.app');
      expect(update, isNotNull);
      expect(update!.storeVersion, '2.7.0');
      expect(update.installedVersion, '2.6.1');
      expect(
        update.appStoreUri.toString(),
        'itms-apps://apps.apple.com/app/id6752509504',
      );
      expect(
        update.webUri.toString(),
        'https://apps.apple.com/app/id6752509504',
      );
    });

    test('lets the app through when it is as new as the store', () async {
      expect(await service(installedVersion: '2.7.0').check(), isNull);
    });

    test(
      'lets a build newer than the store through (TestFlight, review)',
      () async {
        expect(await service(installedVersion: '2.8.0').check(), isNull);
      },
    );

    test('ignores a release this device is too old to install', () async {
      final update =
          await service(
            installedVersion: '2.6.1',
            os: 'Version 15.8 (Build 19H370)',
            client: MockClient(
              (_) async => http.Response(lookup(minOs: '16.0'), 200),
            ),
          ).check();
      expect(update, isNull);
    });

    test('never asks the store off iOS', () async {
      var asked = false;
      final update =
          await service(
            installedVersion: '1.0.0',
            isIOS: false,
            client: MockClient((_) async {
              asked = true;
              return http.Response(lookup(), 200);
            }),
          ).check();
      expect(update, isNull);
      expect(asked, isFalse);
    });

    test('offline with nothing on record: lets the app through', () async {
      final update =
          await service(
            installedVersion: '2.6.1',
            client: MockClient(
              (_) async => throw const SocketException('offline'),
            ),
          ).check();
      expect(update, isNull);
    });

    test(
      'offline: still requires an update the store reported before',
      () async {
        await service(installedVersion: '2.6.1').check();

        final offline = service(
          installedVersion: '2.6.1',
          client: MockClient(
            (_) async => throw const SocketException('offline'),
          ),
        );
        final update = await offline.check();
        expect(update?.storeVersion, '2.7.0');

        // Once updated, the remembered release no longer blocks.
        final updated = service(
          installedVersion: '2.7.0',
          client: MockClient(
            (_) async => throw const SocketException('offline'),
          ),
        );
        expect(await updated.check(), isNull);
      },
    );

    test('a server error falls back to the remembered release', () async {
      await service(installedVersion: '2.6.1').check();
      final update =
          await service(
            installedVersion: '2.6.1',
            client: MockClient((_) async => http.Response('oops', 503)),
          ).check();
      expect(update?.storeVersion, '2.7.0');
    });

    test(
      'an app the store no longer lists is let through and forgotten',
      () async {
        await service(installedVersion: '2.6.1').check();
        final empty = MockClient(
          (_) async => http.Response('{"resultCount":0,"results":[]}', 200),
        );
        expect(
          await service(installedVersion: '2.6.1', client: empty).check(),
          isNull,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AppUpdateService.cacheKey), isNull);
      },
    );
  });

  group('server minimum build', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    PackageInfo installed({String version = '2.14.0', String build = '22'}) =>
        PackageInfo(
          appName: 'Bojang',
          packageName: 'com.projectmira.bojang',
          version: version,
          buildNumber: build,
        );

    ServerConfig minimum({
      int ios = 0,
      int android = 0,
    }) => ServerConfig.fromJson({
      'min_supported_build': {'ios': ios, 'android': android},
      'update': {
        'message': 'This version stopped working. Please update.',
        'store_url': {
          'android':
              'https://play.google.com/store/apps/details?id=com.projectmira.bojang',
        },
      },
    });

    AppUpdateService service({
      required ServerConfig? config,
      String build = '22',
      bool isIOS = false,
      bool isAndroid = true,
      http.Client? client,
    }) => AppUpdateService(
      client: client ?? MockClient((_) async => http.Response('{}', 404)),
      packageInfo: () async => installed(build: build),
      osVersion: () => 'Version 18.4 (Build 22E238)',
      isIOS: isIOS,
      isAndroid: isAndroid,
      serverConfig: () async => config,
    );

    test('walls an Android build below the minimum', () async {
      final update =
          await service(config: minimum(android: 30), build: '29').check();
      expect(update, isNotNull);
      expect(update!.reason, UpdateReason.belowMinimumBuild);
      expect(update.storeName, 'Play Store');
      expect(update.storeVersion, isEmpty);
      expect(update.message, 'This version stopped working. Please update.');
      expect(
        update.storeUris.first.toString(),
        'market://details?id=com.projectmira.bojang',
      );
      expect(update.storeUris.map((u) => u.scheme), contains('https'));
    });

    test('lets the minimum build and newer ones in', () async {
      expect(
        await service(config: minimum(android: 30), build: '30').check(),
        isNull,
      );
      expect(
        await service(config: minimum(android: 30), build: '31').check(),
        isNull,
      );
    });

    test('uses the minimum of its own platform', () async {
      expect(
        await service(config: minimum(ios: 99), build: '22').check(),
        isNull,
      );
      final ios =
          await service(
            config: minimum(ios: 63),
            build: '62',
            isIOS: true,
            isAndroid: false,
          ).check();
      expect(ios?.reason, UpdateReason.belowMinimumBuild);
      expect(ios?.storeName, 'App Store');
    });

    test('the server wall comes before the App Store lookup on iOS', () async {
      var asked = false;
      final update =
          await service(
            config: minimum(ios: 63),
            build: '62',
            isIOS: true,
            isAndroid: false,
            client: MockClient((_) async {
              asked = true;
              return http.Response('{}', 200);
            }),
          ).check();
      expect(update?.reason, UpdateReason.belowMinimumBuild);
      expect(asked, isFalse);
    });

    test('fails open without a config, or when it cannot be read', () async {
      expect(await service(config: null, build: '1').check(), isNull);
      expect(
        await service(config: ServerConfig.failOpen, build: '1').check(),
        isNull,
      );
      final broken = AppUpdateService(
        client: MockClient((_) async => http.Response('{}', 404)),
        packageInfo: () async => installed(build: '1'),
        isIOS: false,
        isAndroid: true,
        serverConfig: () async => throw StateError('no config'),
      );
      expect(await broken.check(), isNull);
    });

    test('a non-numeric build number never walls', () async {
      expect(
        await service(config: minimum(android: 30), build: '').check(),
        isNull,
      );
    });

    test('no wall on platforms other than iOS and Android', () async {
      expect(
        await service(
          config: minimum(ios: 99, android: 99),
          build: '1',
          isAndroid: false,
        ).check(),
        isNull,
      );
    });
  });
}
