import 'package:bojang/services/app_update_service.dart';
import 'package:bojang/widgets/update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUpdateService extends AppUpdateService {
  _FakeUpdateService(this.answers) : super(isIOS: true);

  /// Answers for successive checks; the last one repeats.
  final List<RequiredUpdate?> answers;
  int calls = 0;

  @override
  Future<RequiredUpdate?> check() async {
    final answer = answers[calls.clamp(0, answers.length - 1)];
    calls++;
    return answer;
  }
}

const _update = RequiredUpdate(
  installedVersion: '2.6.1',
  storeVersion: '2.7.0',
  appStoreId: 6752509504,
);

void main() {
  Future<void> pumpGate(
    WidgetTester tester,
    AppUpdateService service, {
    Future<bool> Function(Uri)? openUrl,
    VoidCallback? onAppTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: onAppTap ?? () {},
              child: const Text('Start a Lesson'),
            ),
          ),
        ),
        builder:
            (context, child) =>
                UpdateGate(service: service, openUrl: openUrl, child: child!),
      ),
    );
    await tester.pump();
  }

  testWidgets('an up-to-date app is left alone', (tester) async {
    var tapped = false;
    await pumpGate(
      tester,
      _FakeUpdateService([null]),
      onAppTap: () => tapped = true,
    );

    expect(find.text('Time to update'), findsNothing);
    await tester.tap(find.text('Start a Lesson'));
    expect(tapped, isTrue);
  });

  testWidgets('an out-of-date app is covered and cannot be used', (
    tester,
  ) async {
    var tapped = false;
    await pumpGate(
      tester,
      _FakeUpdateService([_update]),
      onAppTap: () => tapped = true,
    );

    expect(find.text('Time to update'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.textContaining('Version 2.7.0'), findsOneWidget);
    // No way to dismiss it.
    expect(find.textContaining('Later'), findsNothing);
    expect(find.byType(CloseButton), findsNothing);

    await tester.tap(find.text('Start a Lesson'), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('Update now opens the App Store, falling back to the web page', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpGate(
      tester,
      _FakeUpdateService([_update]),
      openUrl: (uri) async {
        opened.add(uri);
        return uri.scheme == 'https'; // no App Store app, like the simulator
      },
    );

    await tester.tap(find.text('Update now'));
    await tester.pump();

    expect(opened.map((u) => u.toString()), [
      'itms-apps://apps.apple.com/app/id6752509504',
      'https://apps.apple.com/app/id6752509504',
    ]);
    // Still blocked after coming back without updating.
    expect(find.text('Time to update'), findsOneWidget);
  });

  testWidgets('returning to the app re-checks while the notice is up', (
    tester,
  ) async {
    final service = _FakeUpdateService([_update, null]);
    await pumpGate(tester, service);
    expect(find.text('Time to update'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(service.calls, 2);
    expect(find.text('Time to update'), findsNothing);
  });

  testWidgets('an up-to-date app is not re-checked on every resume', (
    tester,
  ) async {
    final service = _FakeUpdateService([null]);
    await pumpGate(tester, service);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(service.calls, 1);
  });
}
