// Screenshots of every main screen in light and dark, on whatever simulator
// it runs on (ci/scripts/e2e.sh --screens runs it on iPhone SE, iPhone 16 Pro
// Max and iPad Pro 13"). Saved as shots/screens_test--<device>-<theme>-<screen>.png.
// Flags layout overflows and text cut short, per screen (REPORT: lines);
// overflows fail the test, clipped text is listed for review.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/screens.dart';

void main() {
  initBinding();

  testWidgets('screenshots, light and dark', (tester) async {
    final rows = <String>[];
    final overflows = <String>[];
    String device = '';

    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';
      await launchApp(tester, seed: (p) => seedExistingLearner(p, dark: dark));
      await waitFor(tester, find.text('Practice'), timeout: 30, reason: 'main tabs');
      await wait(tester, 4);
      if (!dark) await grantXp(3);
      device = deviceTag(tester);

      for (final screen in mainScreens) {
        final errors = <String>[];
        final saved = FlutterError.onError;
        FlutterError.onError = (d) {
          final text = d.exceptionAsString();
          if (text.contains('overflowed') || text.contains('OVERFLOWING')) {
            errors.add(text.split('\n').first);
          } else if (!text.contains('HTTP request failed')) {
            saved?.call(d);
          }
        };
        try {
          await screen.open(tester);
          await wait(tester, 1.5);
          await shot('$device-$theme-${screen.name}');
        } finally {
          FlutterError.onError = saved;
        }
        final clipped = clippedTexts(tester);
        rows.add('| $device | $theme | ${screen.name} | '
            '${errors.isEmpty ? 'none' : errors.join('; ')} | '
            '${clipped.isEmpty ? 'none' : clipped.map((c) => '"$c"').join(', ')} |');
        overflows.addAll(errors.map((e) => '$device $theme ${screen.name}: $e'));
        await backToTabs(tester);
      }
    }

    final lines = [
      '',
      '## Screenshots ($device)',
      '',
      '| Device | Theme | Screen | Overflow | Text cut short |',
      '|---|---|---|---|---|',
      ...rows,
      '',
    ];
    for (final l in lines) {
      debugPrint('REPORT:$l');
    }
    expect(overflows, isEmpty, reason: 'layout overflow');
  });
}
