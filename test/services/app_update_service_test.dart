import 'dart:convert';
import 'dart:io';

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
}
