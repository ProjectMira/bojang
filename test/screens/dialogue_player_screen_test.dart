import 'package:bojang/models/dialogue.dart';
import 'package:bojang/models/romanisation.dart';
import 'package:bojang/screens/dialogue_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/dialogue_test.dart' show dialogueJson;

void main() {
  late List<String> played;
  late List<List<DialogueAnswer>> submitted;
  late List<String> completedNodes;

  Future<void> pump(
    WidgetTester tester, {
    TransliterationMode mode = TransliterationMode.phonetics,
    bool enabled = true,
    Size size = const Size(390, 844),
  }) async {
    played = [];
    submitted = [];
    completedNodes = [];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DialoguePlayerScreen(
          dialogueId: 'dlg-greetings',
          loader: (_) async => Dialogue.fromJson(dialogueJson()),
          playAudio: (url) async => played.add(url),
          submit: (_, answers) async {
            submitted.add(answers);
            return true;
          },
          completeNode: (nodeId, correct, total) async {
            completedNodes.add('$nodeId $correct/$total');
          },
          readingMode: mode,
          enabled: enabled,
          autoplay: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lines appear one by one and autoplay their audio', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('བཀྲ་ཤིས་བདེ་ལེགས།'), findsWidgets);
    expect(find.text('trashi delek'), findsOneWidget);
    expect(find.text('ཐུགས་རྗེ་ཆེ།'), findsNothing);
    expect(played, ['https://x/01.mp3']);

    await tester.tap(find.text('Next line'));
    await tester.pumpAndSettle();
    expect(find.text('ཐུགས་རྗེ་ཆེ།'), findsOneWidget);
    // The second line has no clip: nothing more is played.
    expect(played, ['https://x/01.mp3']);
    expect(find.text('Answer questions'), findsOneWidget);
  });

  testWidgets('tapping a line shows its English', (tester) async {
    await pump(tester);
    expect(find.text('Hello!'), findsNothing);
    await tester.tap(find.text('trashi delek'));
    await tester.pumpAndSettle();
    expect(find.text('Hello!'), findsOneWidget);
    await tester.tap(find.text('trashi delek'));
    await tester.pumpAndSettle();
    expect(find.text('Hello!'), findsNothing);
  });

  testWidgets('phonetics follow the Reading Help setting', (tester) async {
    await pump(tester, mode: TransliterationMode.wylie);
    expect(find.text('trashi delek'), findsNothing);
    expect(find.text('bkra shis bde legs'), findsOneWidget);
  });

  testWidgets('questions are answered, then submitted', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Next line'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Answer questions'));
    await tester.pumpAndSettle();
    expect(find.text('How is Pema?'), findsOneWidget);
    await tester.tap(find.text('She is tired'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 1 right'), findsOneWidget);
    expect(submitted.single.single.optionId, 'q1-a');
    expect(submitted.single.single.correct, isFalse);
    // Finishing counts the dialogue's path node.
    expect(completedNodes, ['dialogue:dlg-greetings 0/1']);
  });

  testWidgets('kill switch shows a message instead', (tester) async {
    await pump(tester, enabled: false);
    expect(find.textContaining('switched off'), findsOneWidget);
    expect(played, isEmpty);
  });

  testWidgets('fits an iPad in dark mode', (tester) async {
    played = [];
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DialoguePlayerScreen(
          dialogueId: 'dlg-greetings',
          loader: (_) async => Dialogue.fromJson(dialogueJson()),
          playAudio: (url) async => played.add(url),
          submit: (_, _) async => true,
          readingMode: TransliterationMode.both,
          enabled: true,
          autoplay: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(played, isEmpty);
    expect(find.byType(SpeakerAvatar), findsOneWidget);
  });

  test('route /dialogue/<id>', () {
    final route = DialoguePlayerScreen.onGenerateRoute(
      const RouteSettings(name: '/dialogue/dlg-tea'),
    );
    expect(route, isNotNull);
    expect(
      DialoguePlayerScreen.onGenerateRoute(const RouteSettings(name: '/other')),
      isNull,
    );
    expect(DialoguePlayerScreen.routeFor('dlg-tea'), '/dialogue/dlg-tea');
  });
}
