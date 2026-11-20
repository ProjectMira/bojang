import 'package:bojang/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('coordinates are rounded to about 10 km', () {
    expect(LocationService.roundCoordinate(27.71234), 27.7);
    expect(LocationService.roundCoordinate(85.36789), 85.4);
    expect(LocationService.roundCoordinate(-33.86), -33.9);
  });

  test('sharing is off until the learner turns it on', () async {
    expect(await LocationService.instance.sharingEnabled, isFalse);
  });

  Future<void> pumpPrompt(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => LocationService.instance.maybePromptAfterLesson(context),
            child: const Text('done'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
  }

  testWidgets('the explanation shows once, and "Not now" shares nothing', (tester) async {
    await pumpPrompt(tester);
    expect(find.text('Where are you learning from?'), findsOneWidget);
    expect(find.textContaining('never your exact'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Where are you learning from?'), findsNothing);
    expect(await LocationService.instance.sharingEnabled, isFalse);

    // Never asked again.
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.text('Where are you learning from?'), findsNothing);
  });

  testWidgets('no prompt for a learner who was already asked', (tester) async {
    SharedPreferences.setMockInitialValues({'location_prompted': true});
    await pumpPrompt(tester);
    expect(find.text('Where are you learning from?'), findsNothing);
  });
}
