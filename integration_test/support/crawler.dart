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
  _Tappable(this.key, this.label, this.rect);
  final String key;
  final String label;
  final Rect rect;
}

SemanticsNode? _root() {
  final view = RendererBinding.instance.renderViews.first;
  return view.owner?.semanticsOwner?.rootSemanticsNode;
}

/// Enabled widgets that react to a tap.
bool _isTappable(Widget w) =>
    (w is InkResponse && (w.onTap != null || w.onLongPress != null)) ||
    (w is GestureDetector && w.onTap != null) ||
    (w is ButtonStyleButton && w.onPressed != null) ||
    (w is IconButton && w.onPressed != null) ||
    (w is FloatingActionButton && w.onPressed != null) ||
    (w is ListTile && w.onTap != null) ||
    (w is Switch && w.onChanged != null) ||
    (w is SwitchListTile && w.onChanged != null) ||
    (w is Checkbox && w.onChanged != null) ||
    (w is CheckboxListTile && w.onChanged != null) ||
    (w is ActionChip && w.onPressed != null) ||
    (w is ChoiceChip && w.onSelected != null) ||
    (w is FilterChip && w.onSelected != null);

/// A readable name: tooltip, the texts inside, an icon, or the type.
String _widgetLabel(Element e) {
  final w = e.widget;
  if (w is IconButton && w.tooltip != null) return w.tooltip!;
  final texts = <String>[];
  String? icon;
  void visit(Element c) {
    final cw = c.widget;
    if (cw is Text) {
      final t = (cw.data ?? cw.textSpan?.toPlainText() ?? '').trim();
      if (t.isNotEmpty) texts.add(t);
    } else if (cw is RichText) {
      final t = cw.text.toPlainText().trim();
      if (t.isNotEmpty && texts.isEmpty) texts.add(t);
    } else if (cw is Icon && icon == null && cw.icon != null) {
      icon = 'icon ${cw.icon!.codePoint.toRadixString(16)}';
    } else if (cw is Tooltip && texts.isEmpty) {
      texts.add(cw.message ?? '');
    }
    if (texts.length < 3) c.visitChildren(visit);
  }

  e.visitChildren(visit);
  var s = texts.where((t) => t.isNotEmpty).take(2).join(' / ').replaceAll('\n', ' ');
  if (s.isEmpty) s = icon ?? '(${w.runtimeType})';
  return s.length > 60 ? '${s.substring(0, 57)}...' : s;
}

/// Every enabled tappable widget whose centre is on screen and actually
/// receives a tap there (not covered, not off-stage). Nested ones that share
/// a centre (a button and its InkWell) count once.
List<_Tappable> _tappables(WidgetTester tester, Size screen, Set<String> skipLabels) {
  final out = <_Tappable>[];
  final seen = <String, int>{};
  final centres = <String>{};
  final candidates = find.byWidgetPredicate(_isTappable).hitTestable();
  for (final e in candidates.evaluate()) {
    // The app bar's back button closes the screen being crawled.
    if (e.findAncestorWidgetOfExactType<BackButton>() != null) continue;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    final c = rect.center;
    if (c.dx <= 0 || c.dy <= 0 || c.dx >= screen.width || c.dy >= screen.height) continue;
    final centreKey = '${(c.dx / 6).round()}:${(c.dy / 6).round()}';
    if (!centres.add(centreKey)) continue;
    final label = _widgetLabel(e);
    if (skipLabels.any((s) => s == 'Back' ? label == 'Back' : label.contains(s))) continue;
    final n = seen[label] = (seen[label] ?? 0) + 1;
    out.add(_Tappable('$label#$n', label, rect));
  }
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
  'Back', // the app bar's back button closes the screen being crawled

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
            tester,
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
      debugPrint('E2E: crawl $screen tap "${t.label}"');
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
