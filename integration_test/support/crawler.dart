// Generic screen crawler: taps every enabled tappable thing the semantics
// tree exposes on a screen, checks what happened, and puts the screen back.
//
// After each tap it records:
//   * route   - a page, dialog or sheet was pushed (then popped again);
//   * changed - the screen's semantics changed (text, toggles, selection);
//   * sound   - nothing visible changed but audio was played;
//   * none    - nothing observable happened (a possible dead button);
//   * error   - an exception or a layout overflow was reported.
// Errors fail the test; "none" rows are listed for review in the report.
// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

class TapResult {
  TapResult(this.label, this.outcome, [this.detail = '']);
  final String label;
  final String outcome;
  final String detail;
}

class ScreenReport {
  ScreenReport(this.screen);
  final String screen;
  final List<TapResult> taps = [];
  int count(String outcome) => taps.where((t) => t.outcome == outcome).length;
}

final List<ScreenReport> crawlReports = [];

/// Errors reported through FlutterError while crawling.
final List<String> _errors = [];
FlutterExceptionHandler? _savedOnError;
int _audioCalls = 0;

const _audioChannels = [
  'xyz.luan/audioplayers',
  'xyz.luan/audioplayers.global',
];

void _startCapture() {
  _savedOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    // Network images that 404 in the seeded data are not UI bugs.
    if (text.contains('HTTP request failed') || text.contains('NetworkImage'))
      return;
    _errors.add(text.split('\n').first);
  };
  for (final ch in _audioChannels) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(ch), (
      call,
    ) async {
      if (call.method == 'play' ||
          call.method == 'resume' ||
          call.method == 'setSourceUrl' ||
          call.method == 'setSourceBytes') {
        _audioCalls++;
      }
      if (call.method == 'getDuration' || call.method == 'getCurrentPosition')
        return 1000;
      return null;
    });
  }
}

void _stopCapture() {
  FlutterError.onError = _savedOnError;
  for (final ch in _audioChannels) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(ch),
      null,
    );
  }
}

class _Tappable {
  _Tappable(this.key, this.label, this.rect, this.id);
  final String key;
  final String label;
  final Rect rect;
  final int id;
}

SemanticsNode? _root() {
  final view = RendererBinding.instance.renderViews.first;
  return view.owner?.semanticsOwner?.rootSemanticsNode;
}

Rect _globalRect(SemanticsNode node) {
  var rect = node.rect;
  SemanticsNode? n = node;
  while (n != null && n.parent != null) {
    if (n.transform != null)
      rect = MatrixUtils.transformRect(n.transform!, rect);
    n = n.parent;
  }
  return rect;
}

String _nodeLabel(SemanticsData d) {
  final parts = [d.label, d.value, d.tooltip, d.hint]
      .where((s) => s.trim().isNotEmpty)
      .map((s) => s.replaceAll('\n', ' ').trim());
  final s = parts.join(' / ');
  return s.isEmpty
      ? '(unlabelled)'
      : (s.length > 60 ? '${s.substring(0, 57)}...' : s);
}

/// Every enabled node with a tap action that is on screen.
List<_Tappable> _tappables(Size screen, Set<String> skipLabels) {
  final out = <_Tappable>[];
  final seen = <String, int>{};
  void visit(SemanticsNode node) {
    final d = node.getSemanticsData();
    final disabled =
        d.hasFlag(SemanticsFlag.hasEnabledState) &&
        !d.hasFlag(SemanticsFlag.isEnabled);
    if (d.hasAction(SemanticsAction.tap) && !disabled && !node.isInvisible) {
      final rect = _globalRect(node);
      final onScreen =
          rect.center.dx > 0 &&
          rect.center.dy > 0 &&
          rect.center.dx < screen.width &&
          rect.center.dy < screen.height;
      final label = _nodeLabel(d);
      if (onScreen && !skipLabels.any((s) => label.contains(s))) {
        final n = seen[label] = (seen[label] ?? 0) + 1;
        out.add(_Tappable('$label#$n', label, rect, node.id));
      }
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  final root = _root();
  if (root != null) visit(root);
  return out;
}

String _fingerprint() {
  final b = StringBuffer();
  void visit(SemanticsNode node) {
    final d = node.getSemanticsData();
    b
      ..write(d.label)
      ..write('|')
      ..write(d.value)
      ..write('|')
      ..write(d.flags)
      ..write(';');
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  final root = _root();
  if (root != null) visit(root);
  return b.toString();
}

final _scopeFinder = find.byWidgetPredicate(
  (w) => w.runtimeType.toString().startsWith('_ModalScope'),
  skipOffstage: false,
);

int _routeCount() => _scopeFinder.evaluate().length;

/// Pops routes (pages, dialogs, sheets) until only [count] remain.
Future<void> _popTo(WidgetTester tester, int count) async {
  for (var i = 0; i < 6 && _routeCount() > count; i++) {
    final top = _scopeFinder.evaluate().last;
    final nav = Navigator.maybeOf(top);
    if (nav == null) break;
    nav.pop(); // forced: skips "Keep going?" style PopScope prompts
    await wait(tester, 0.7);
  }
}

/// Labels the crawler never taps: they act on the account or leave the app.
const defaultSkip = <String>{
  'Sign out',
  'Log out',
  'Delete account',
  'Delete my account',
  'Reset progress',
  'Erase',
};

/// Crawls the screen currently shown. [restore] brings the screen back when
/// a tap replaced it without pushing a route (e.g. switched a tab).
Future<ScreenReport> crawlScreen(
  WidgetTester tester,
  String screen, {
  Set<String> skip = const {},
  Future<void> Function()? restore,
  int maxTaps = 45,
  bool scroll = true,
}) async {
  final report = ScreenReport(screen);
  crawlReports.add(report);
  final handle = tester.ensureSemantics();
  _startCapture();
  try {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final skipLabels = {...defaultSkip, ...skip};
    final done = <String>{};
    final baseRoutes = _routeCount();
    var scrolls = 0;
    while (report.taps.length < maxTaps) {
      await wait(tester, 0.3);
      final todo =
          _tappables(
            size,
            skipLabels,
          ).where((t) => !done.contains(t.key)).toList();
      if (todo.isEmpty) {
        if (!scroll || scrolls >= 8) break;
        final scrollables = find.byType(Scrollable).hitTestable();
        if (scrollables.evaluate().isEmpty) break;
        final before = _fingerprint();
        await tester.drag(
          scrollables.first,
          Offset(0, -size.height * 0.6),
          warnIfMissed: false,
        );
        await wait(tester, 0.6);
        scrolls++;
        if (_fingerprint() == before) break;
        continue;
      }
      final t = todo.first;
      done.add(t.key);
      final before = _fingerprint();
      final errorsBefore = _errors.length;
      final audioBefore = _audioCalls;
      await tester.tapAt(t.rect.center);
      await wait(tester, 1.2);
      final routes = _routeCount();
      String outcome;
      var detail = '';
      if (_errors.length > errorsBefore) {
        outcome = 'error';
        detail = _errors.sublist(errorsBefore).join('; ');
        await shot('crawl-error-$screen-${report.taps.length}');
      } else if (routes > baseRoutes) {
        outcome = 'route';
        await shot('crawl-$screen-${report.taps.length}');
      } else if (_fingerprint() != before) {
        outcome = 'changed';
      } else if (_audioCalls > audioBefore) {
        outcome = 'sound';
      } else {
        outcome = 'none';
      }
      report.taps.add(TapResult(t.label, outcome, detail));
      if (routes > baseRoutes) await _popTo(tester, baseRoutes);
      if (restore != null && outcome != 'none') await restore();
    }
  } finally {
    _stopCapture();
    handle.dispose();
  }
  return report;
}

/// Markdown coverage table, printed as REPORT: lines for ci/scripts/e2e.sh.
void printCrawlReport() {
  final lines = <String>[
    '',
    '## Crawler coverage',
    '',
    '| Screen | Tapped | Route | Changed | Sound | No change | Errors |',
    '|---|---|---|---|---|---|---|',
    for (final r in crawlReports)
      '| ${r.screen} | ${r.taps.length} | ${r.count('route')} | ${r.count('changed')} | '
          '${r.count('sound')} | ${r.count('none')} | ${r.count('error')} |',
    '',
  ];
  final none = [
    for (final r in crawlReports)
      for (final t in r.taps.where((t) => t.outcome == 'none'))
        '- ${r.screen}: "${t.label}"',
  ];
  if (none.isNotEmpty) {
    lines
      ..add(
        'Taps with no observable effect (review: dead button or effect the crawler cannot see):',
      )
      ..addAll(none)
      ..add('');
  }
  final errors = [
    for (final r in crawlReports)
      for (final t in r.taps.where((t) => t.outcome == 'error'))
        '- ${r.screen}: "${t.label}": ${t.detail}',
  ];
  if (errors.isNotEmpty) {
    lines
      ..add('Errors:')
      ..addAll(errors)
      ..add('');
  }
  for (final l in lines) {
    debugPrint('REPORT:$l');
  }
}
