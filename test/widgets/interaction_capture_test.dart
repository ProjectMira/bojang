import 'package:bojang/services/event_tracker.dart';
import 'package:bojang/widgets/interaction_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late EventTracker tracker;

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

  Future<void> pumpApp(WidgetTester tester, Widget body) async {
    tracker = EventTracker.forTest();
    tracker.sender = (_) async => null;
    await tester.runAsync(tracker.start);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [tracker.routeObserver],
      builder: (context, child) => InteractionCapture(tracker: tracker, child: child!),
      home: Scaffold(body: body),
    ));
  }

  Map<String, Object?> lastOf(String event) => Map<String, Object?>.from(
        tracker.queue.lastWhere((e) => e['event'] == event)['properties'] as Map,
      );

  Future<void> done(WidgetTester tester) => tester.runAsync(tracker.stop);

  testWidgets('a button tap reports the button and its label', (tester) async {
    await pumpApp(
      tester,
      Center(child: ElevatedButton(onPressed: () {}, child: const Text('Start lesson'))),
    );
    await tester.tap(find.text('Start lesson'));
    await tester.pump();

    final tap = lastOf('tap');
    expect(tap['widget'], 'ElevatedButton');
    expect(tap['kind'], 'button');
    expect(tap['target'], 'Start lesson');
    expect(tap['dead'], isNull);
    expect(tap['x'], closeTo(0.5, 0.05));
    expect(tracker.queue.last['screen'], 'root');
    await done(tester);
  });

  testWidgets('a switch reports its state and the row title', (tester) async {
    await pumpApp(
      tester,
      ListTile(
        title: const Text('Theme'),
        subtitle: const Text('Light Mode'),
        trailing: Switch(value: false, onChanged: (_) {}),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();

    final tap = lastOf('tap');
    expect(tap['kind'], 'switch');
    expect(tap['value'], false);
    expect(tap['target'], 'Theme · Light Mode');
    await done(tester);
  });

  testWidgets('a tile tap reports its texts and key', (tester) async {
    await pumpApp(
      tester,
      ListTile(
        key: const ValueKey('topic_colors'),
        title: const Text('Colors'),
        onTap: () {},
      ),
    );
    await tester.tap(find.text('Colors'));
    await tester.pump();

    final tap = lastOf('tap');
    expect(tap['widget'], 'ListTile');
    expect(tap['target'], 'Colors');
    expect(tap['key'], 'topic_colors');
    await done(tester);
  });

  testWidgets('an icon-only button reports IconButton and the icon name', (tester) async {
    await pumpApp(
      tester,
      Center(child: IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back))),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();

    final tap = lastOf('tap');
    expect(tap['widget'], 'IconButton');
    expect(tap['kind'], 'button');
    expect(tap['target'], 'icon:back');
    await done(tester);
  });

  testWidgets('a tap on plain text is a dead tap with that text', (tester) async {
    await pumpApp(tester, const Center(child: Text('Just a heading')));
    await tester.tap(find.text('Just a heading'));
    await tester.pump();

    final tap = lastOf('tap');
    expect(tap['dead'], true);
    expect(tap['target'], 'Just a heading');
    await done(tester);
  });

  testWidgets('typed text is never recorded, only the field label', (tester) async {
    await pumpApp(
      tester,
      const Padding(
        padding: EdgeInsets.all(40),
        child: TextField(decoration: InputDecoration(labelText: 'Your name')),
      ),
    );
    await tester.enterText(find.byType(TextField), 'secret words');
    await tester.tap(find.byType(TextField));
    await tester.pump();

    final tap = lastOf('tap');
    expect(tap['kind'], 'text_field');
    expect(tap['target'], 'Your name');
    expect(tracker.queue.toString(), isNot(contains('secret words')));
    await done(tester);
  });

  testWidgets('labels inside PostHogMaskWidget are left out', (tester) async {
    await pumpApp(
      tester,
      PostHogMaskWidget(
        child: Center(
          child: TextButton(onPressed: () {}, child: const Text('me@example.com')),
        ),
      ),
    );
    await tester.tap(find.text('me@example.com'));
    await tester.pump();

    final tap = lastOf('tap');
    expect(tap['masked'], true);
    expect(tap['target'], isNull);
    expect(tap['widget'], 'TextButton');
    await done(tester);
  });

  testWidgets('long press, swipe and scroll are recorded', (tester) async {
    await pumpApp(
      tester,
      ListView(children: [for (var i = 0; i < 60; i++) ListTile(title: Text('Row $i'))]),
    );
    // Test pointers carry no real timestamps, so give them some.
    final press = await tester.createGesture();
    await press.down(tester.getCenter(find.text('Row 1')),
        timeStamp: const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 700));
    await press.up(timeStamp: const Duration(milliseconds: 1700));
    await tester.pump();
    expect(lastOf('long_press')['target'], 'Row 1');

    await tester.fling(find.byType(ListView), const Offset(0, -400), 1500);
    await tester.pumpAndSettle();
    expect(lastOf('swipe')['direction'], 'up');
    final scroll = lastOf('scroll');
    expect(scroll['axis'], 'vertical');
    expect(scroll['depth'] as num, greaterThan(0));
    await done(tester);
  });

  testWidgets('three fast taps on one spot add a rage tap', (tester) async {
    await pumpApp(tester, const Center(child: Text('Broken button')));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Broken button'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final rage = lastOf('rage_tap');
    expect(rage['taps'], 3);
    expect(rage['target'], 'Broken button');
    await done(tester);
  });

  testWidgets('the Remote Config kill switch stops tap capture', (tester) async {
    await pumpApp(
      tester,
      Center(child: ElevatedButton(onPressed: () {}, child: const Text('Go'))),
    );
    tracker.captureTaps = false;
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(tracker.queue.where((e) => e['event'] == 'tap'), isEmpty);
    await done(tester);
  });

  testWidgets('nothing is recorded while tracking is off', (tester) async {
    await pumpApp(
      tester,
      Center(child: ElevatedButton(onPressed: () {}, child: const Text('Go'))),
    );
    await tester.runAsync(tracker.stop);
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(tracker.queue, isEmpty);
  });
}
