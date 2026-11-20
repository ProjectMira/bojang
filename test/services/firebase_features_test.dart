import 'package:bojang/services/app_check_service.dart';
import 'package:bojang/services/crash_reporting.dart';
import 'package:bojang/services/event_tracker.dart';
import 'package:bojang/services/remote_settings.dart';
import 'package:bojang/widgets/announcement_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Without a configured Firebase app (tests, web, Android today) every
/// Firebase feature must stay out of the way and fall back to defaults.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Remote Config falls back to the defaults and applies the kill switches', () async {
    final tracker = EventTracker.instance
      ..captureTaps = false
      ..uploadsEnabled = false;
    await RemoteSettings.init();

    expect(RemoteSettings.getBool('tap_capture_enabled'), isTrue);
    expect(RemoteSettings.getString('home_announcement_title'), '');
    expect(RemoteSettings.getBool('no_such_key'), isFalse);
    expect(tracker.captureTaps, isTrue);
    expect(tracker.uploadsEnabled, isTrue);
  });

  test('App Check and crash reporting are no-ops without Firebase', () async {
    await AppCheckService.init();
    expect(await AppCheckService.token(), isNull);
    await CrashReporting.init(collect: true);
    expect(CrashReporting.performanceOn, isFalse);
    CrashReporting.setUser('uid-1');
    CrashReporting.setKey('screen', 'quiz');
    CrashReporting.recordError(StateError('x'), StackTrace.current);
  });

  test('the timed HTTP client passes requests through untouched', () async {
    final client = PerformanceHttpClient(MockClient((request) async {
      expect(request.url.query, 'a=1');
      return http.Response('{"ok":true}', 201, headers: {'content-type': 'application/json'});
    }));
    final response = await client.post(Uri.parse('https://example.com/x?a=1'), body: '{}');
    expect(response.statusCode, 201);
    expect(response.body, '{"ok":true}');
  });

  testWidgets('the announcement banner stays hidden with no title', (tester) async {
    await RemoteSettings.init();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AnnouncementBanner())));
    await tester.pump();
    expect(find.byIcon(Icons.campaign_rounded), findsNothing);
  });

  test('paused uploads keep events queued', () async {
    final tracker = EventTracker.forTest();
    var calls = 0;
    tracker.sender = (_) async {
      calls++;
      return 202;
    };
    await tracker.start();
    tracker.uploadsEnabled = false;
    tracker.record('tap');
    await tracker.flush();
    expect(calls, 0);
    expect(tracker.queue.map((e) => e['event']), contains('tap'));

    tracker.uploadsEnabled = true;
    await tracker.flush();
    expect(calls, greaterThan(0));
    expect(tracker.queue, isEmpty);
    await tracker.stop();
  });
}
