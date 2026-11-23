import 'package:bojang/widgets/offline_lessons_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool online,
    required int ready,
    int pending = 0,
    bool enabled = true,
    Brightness brightness = Brightness.light,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: OfflineLessonsBanner(
          online: ValueNotifier(online),
          ready: ValueNotifier(ready),
          pending: ValueNotifier(pending),
          enabled: enabled,
        ),
      ),
    ),
  );

  testWidgets('online with lessons saved: "2 lessons ready offline"', (
    t,
  ) async {
    await pump(t, online: true, ready: 2);
    expect(find.text('2 lessons ready offline'), findsOneWidget);
  });

  testWidgets('offline: banner with what is ready and what will sync', (
    t,
  ) async {
    await pump(
      t,
      online: false,
      ready: 1,
      pending: 2,
      brightness: Brightness.dark,
    );
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('1 lesson ready offline'), findsOneWidget);
    expect(find.textContaining('2 results will sync'), findsOneWidget);
  });

  testWidgets('hidden online with nothing saved, and when switched off', (
    t,
  ) async {
    await pump(t, online: true, ready: 0);
    expect(find.byType(Container), findsNothing);
    await pump(t, online: false, ready: 2, enabled: false);
    expect(find.text("You're offline"), findsNothing);
  });
}
