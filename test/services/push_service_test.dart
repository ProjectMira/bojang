import 'package:bojang/services/event_tracker.dart';
import 'package:bojang/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tapped notification records `push_opened` with the push's data and
/// opens the tab it names (cold start and background alike).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tracker = EventTracker.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Bojang',
      packageName: 'com.bojang.app',
      version: '2.22.0',
      buildNumber: '1',
      buildSignature: '',
    );
    tracker.sender = (_) async => null;
    await tracker.start();
    PushService.requestedScreen.value = null;
  });

  tearDown(() async {
    await tracker.stop();
    PushService.requestedScreen.value = null;
  });

  List<Map<Object?, Object?>> opened() => [
        for (final e in tracker.queue)
          if (e['event'] == 'push_opened') e['properties'] as Map<Object?, Object?>,
      ];

  test('a push that started the app is recorded with its data', () {
    PushService.instance.handleOpened(
      {
        'kind': 'reminder',
        'screen': 'streak',
        'campaign': 'streak_at_risk',
        'state': 'evening',
        'line_id': 'ev_03',
      },
      messageId: 'm-cold-1',
      launch: 'cold',
    );

    expect(opened(), [
      {
        'kind': 'reminder',
        'screen': 'streak',
        'campaign': 'streak_at_risk',
        'state': 'evening',
        'line_id': 'ev_03',
        'launch': 'cold',
      },
    ]);
    expect(
      tracker.queue.where((e) => e['event'] == 'notification_opened'),
      hasLength(1),
    );
    // MainNavigationScreen reads it after its first frame.
    expect(PushService.requestedScreen.value, 'streak');
  });

  test('a push tapped in the background is counted once per message', () {
    for (var i = 0; i < 2; i++) {
      PushService.instance.handleOpened(
        {'kind': 'streak_saver', 'screen': 'home'},
        messageId: 'm-bg-1',
        launch: 'background',
      );
    }
    expect(opened(), [
      {'kind': 'streak_saver', 'screen': 'home', 'launch': 'background'},
    ]);
    expect(PushService.requestedScreen.value, 'home');
  });

  test('a push without a screen opens nothing, and empty fields are dropped', () {
    PushService.instance.handleOpened(
      {'kind': 'announcement', 'screen': '', 'campaign': 'news'},
      launch: 'background',
    );
    expect(opened(), [
      {'kind': 'announcement', 'campaign': 'news', 'launch': 'background'},
    ]);
    expect(PushService.requestedScreen.value, isNull);
  });
}
