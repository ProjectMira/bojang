import 'package:bojang/screens/memory_match_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('result dialog offers three large, tappable next steps', (
    tester,
  ) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryMatchResultDialog(
            topicName: 'Food',
            totalPairs: 8,
            moves: 12,
            onPlayAgain: () => taps.add('play_again'),
            onChangeTopic: () => taps.add('change_topic'),
            onDone: () => taps.add('done'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('8 Food words in 12 moves'), findsOneWidget);
    for (final key in const [
      'memory_match_play_again',
      'memory_match_change_topic',
      'memory_match_done',
    ]) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThan(200), reason: '$key spans the dialog');
      await tester.tap(find.byKey(ValueKey(key)));
    }
    expect(taps, ['play_again', 'change_topic', 'done']);
  });
}
