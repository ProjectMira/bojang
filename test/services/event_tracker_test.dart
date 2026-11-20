import 'package:bojang/services/event_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Bojang',
      packageName: 'com.bojang.app',
      version: '2.8.0',
      buildNumber: '23',
      buildSignature: '',
    );
  });

  List<String> names(EventTracker t) =>
      t.queue.map((e) => e['event'] as String).toList();

  group('recording and upload', () {
    test('a session starts with display info and events are numbered', () async {
      final t = EventTracker.forTest();
      await t.start();
      t.record('lesson_started', properties: {'topic': 'colors', 'empty': null});

      expect(names(t), containsAllInOrder(['app_session_started', 'lesson_started']));
      final started = t.queue.first;
      expect(started['session_id'], t.sessionId);
      expect((started['properties'] as Map)['cold_start'], true);
      final lesson = t.queue.firstWhere((e) => e['event'] == 'lesson_started');
      expect(lesson['properties'], {'topic': 'colors'});
      expect(lesson['seq'], greaterThan(started['seq'] as int));
      await t.stop();
    });

    test('uploads in batches with the device context and empties the queue', () async {
      final t = EventTracker.forTest();
      final bodies = <Map<String, Object?>>[];
      t.sender = (body) async {
        bodies.add(body);
        return 202;
      };
      await t.start();
      for (var i = 0; i < 30; i++) {
        t.record('tap');
      }
      await t.flush();

      expect(t.queue, isEmpty);
      expect(bodies, isNotEmpty);
      final context = bodies.first['context'] as Map;
      expect(context['app_version'], '2.8.0');
      expect(context['app_build'], '23');
      expect(context['timezone'], contains('UTC'));
      await t.stop();
    });

    test('keeps events while offline or signed out, drops refused batches', () async {
      final t = EventTracker.forTest();
      int? status;
      t.sender = (_) async => status;
      await t.start();
      t.record('tap');

      status = null; // offline
      await t.flush();
      expect(names(t), contains('tap'));

      status = 401; // no valid session yet
      await t.flush();
      expect(names(t), contains('tap'));

      status = 422; // malformed: never retried
      await t.flush();
      expect(t.queue, isEmpty);
      await t.stop();
    });

    test('long strings are shortened before upload', () async {
      final t = EventTracker.forTest();
      await t.start();
      t.record('api_error', properties: {'error': 'x' * 500});
      final props = t.queue.last['properties'] as Map;
      expect((props['error'] as String).length, 200);
      await t.stop();
    });

    test('stop() clears the queue and records nothing more', () async {
      final t = EventTracker.forTest();
      await t.start();
      t.record('tap');
      await t.stop();
      t.record('tap');
      expect(t.queue, isEmpty);
      expect(t.enabled, isFalse);
    });

    test('a session left open by a killed app is closed on next launch', () async {
      final first = EventTracker.forTest();
      first.sender = (_) async => null;
      await first.start();
      first.record('tap');
      first.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final firstSession = first.sessionId;

      // The app is killed in the background: no stop(), a new process starts.
      final second = EventTracker.forTest();
      second.sender = (_) async => null;
      await second.start();
      final ended = second.queue.firstWhere((e) => e['event'] == 'app_session_ended');
      expect(ended['session_id'], firstSession);
      expect((ended['properties'] as Map)['reason'], 'killed_in_background');
      // The queued tap from the first process survives too.
      expect(names(second), contains('tap'));
      await second.stop();
      await first.stop();
    });
  });

  group('screens', () {
    testWidgets('route pushes and pops report screens with dwell time', (tester) async {
      final t = EventTracker.forTest();
      await tester.runAsync(t.start);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [t.routeObserver],
        home: const Text('home'),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'quiz'),
        builder: (_) => const Text('quiz'),
      ));
      await tester.pumpAndSettle();
      navKey.currentState!.pop();
      await tester.pumpAndSettle();

      final screens = t.queue.where((e) => e['event'] == r'$screen').map((e) => e['screen']);
      expect(screens, ['root', 'quiz', 'root']);
      final exit = t.queue.firstWhere((e) => e['event'] == 'screen_exit' && e['screen'] == 'quiz');
      expect((exit['properties'] as Map)['next_screen'], 'root');
      expect((exit['properties'] as Map)['duration_ms'], isA<int>());
      await tester.runAsync(t.stop);
    });

    testWidgets('a name given just before a dialog names the dialog, not the page',
        (tester) async {
      final t = EventTracker.forTest();
      await tester.runAsync(t.start);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [t.routeObserver],
        initialRoute: 'settings',
        onGenerateRoute: (s) => MaterialPageRoute<void>(
          settings: s,
          builder: (_) => const Text('settings'),
        ),
      ));
      t.manualScreen('settings_language');
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('pick')),
      );
      await tester.pumpAndSettle();
      expect(t.currentScreen, 'settings_language');
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(t.currentScreen, 'settings');
      await tester.runAsync(t.stop);
    });
  });
}
