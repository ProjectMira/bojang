// Accessibility guidelines on every main screen: tap target size (iOS 44pt
// and Android 48dp), labelled tap targets and text contrast. Every result is
// reported (REPORT: lines); the test fails if any screen fails one.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/screens.dart';

void main() {
  initBinding();

  testWidgets('accessibility guidelines on main screens', (tester) async {
    await launchApp(tester, seed: seedExistingLearner);
    await waitFor(tester, find.text('Practice'), timeout: 30, reason: 'main tabs');
    await wait(tester, 4);
    await grantXp(3);

    final guidelines = <String, AccessibilityGuideline>{
      'iOS tap target 44pt': iOSTapTargetGuideline,
      'Android tap target 48dp': androidTapTargetGuideline,
      'labelled tap targets': labeledTapTargetGuideline,
      'text contrast': textContrastGuideline,
    };
    final rows = <String>[];
    final failures = <String>[];
    final handle = tester.ensureSemantics();
    for (final screen in mainScreens) {
      await screen.open(tester);
      await wait(tester, 1.5);
      final cells = <String>[];
      for (final g in guidelines.entries) {
        final result = await g.value.evaluate(tester);
        cells.add(result.passed ? 'pass' : 'FAIL');
        if (!result.passed) {
          final reason = result.reason ?? '';
          final first = reason.split('\n').where((l) => l.trim().isNotEmpty).take(6).join(' | ');
          failures.add('- ${screen.name} / ${g.key}: $first');
        }
      }
      rows.add('| ${screen.name} | ${cells.join(' | ')} |');
      await shot('a11y-${screen.name}');
      await backToTabs(tester);
    }
    handle.dispose();

    final lines = [
      '',
      '## Accessibility guidelines',
      '',
      '| Screen | ${guidelines.keys.join(' | ')} |',
      '|---|${List.filled(guidelines.length, '---').join('|')}|',
      ...rows,
      '',
      if (failures.isNotEmpty) ...['Failures (first lines of each):', ...failures, ''],
    ];
    for (final l in lines) {
      debugPrint('REPORT:$l');
    }
    expect(failures, isEmpty, reason: 'accessibility guideline failures');
  });
}
