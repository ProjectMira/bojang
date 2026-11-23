import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bojang/screens/home_page.dart';
import 'package:bojang/services/learning_path_repository.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';
import 'package:bojang/widgets/learning_path_view.dart';

import '../models/learning_path_test.dart' show samplePathJson;

/// Home with the learning path at phone and iPad sizes.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LearningPathRepository.fetchPath = () async => samplePathJson();
  });

  tearDown(LearningPathRepository.debugReset);

  Future<void> pumpHome(WidgetTester tester, Size size, {bool dark = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => ProgressService()),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  for (final (name, size, nodeSize) in [
    ('phone', const Size(390, 844), 72.0),
    ('iPad', const Size(1024, 1366), 92.0),
  ]) {
    testWidgets('$name: units, states, ring and one Start', (tester) async {
      await pumpHome(tester, size);

      expect(find.byType(LearningPathView), findsOneWidget);
      expect(find.text('Tibetan Basics'), findsOneWidget);
      expect(find.text('UNIT 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('path_start_button')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('path_start_button')),
          matching: find.text('1/3'),
        ),
        findsOneWidget,
      ); // sessions done on the Start button
      expect(find.byType(SessionRing), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('The four vowels, next up, session 2 of 3')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Number, locked')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Letters 1, done')), findsOneWidget);

      final button = tester.widget<PathNodeButton>(find.byType(PathNodeButton).first);
      expect(button.size, nodeSize);
      // Centred column with a max width.
      final view = tester.getRect(find.byType(LearningPathView));
      expect(view.width, lessThanOrEqualTo(640));
      expect((view.center.dx - size.width / 2).abs(), lessThan(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping a locked step says why', (tester) async {
    await pumpHome(tester, const Size(390, 844));
    final locked = find.bySemanticsLabel(RegExp('Review: Tibetan Basics, locked'));
    await tester.ensureVisible(locked);
    await tester.tap(locked);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // the active step pulses forever
    expect(find.textContaining('Finish "The four vowels"'), findsOneWidget);
    expect(find.text('Go to "The four vowels"'), findsOneWidget);
  });

  testWidgets('dark mode renders the path', (tester) async {
    await pumpHome(tester, const Size(390, 844), dark: true);
    expect(find.byType(LearningPathView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to the topic home without a path', (tester) async {
    LearningPathRepository.fetchPath = () async => null;
    await pumpHome(tester, const Size(390, 844));
    expect(find.byType(LearningPathView), findsNothing);
    expect(find.text('Start a Lesson'), findsOneWidget);
  });
}
