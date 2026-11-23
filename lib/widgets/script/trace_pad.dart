/// The `trace` exercise: guided tracing stroke by stroke, or freehand
/// writing checked as a whole (see [TraceChecker]).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/script/stroke_data.dart';
import '../../models/script/trace_checker.dart';
import '../../theme/app_tokens.dart';
import '../app_text_style.dart';
import 'stroke_views.dart';

/// [passed] is the verdict; [score] (0-1) is sent as the answer.
typedef TraceDone = void Function(bool passed, double score);

class TracePad extends StatefulWidget {
  const TracePad({
    super.key,
    required this.char,
    required this.freehand,
    required this.onDone,
    this.enabled = true,
    this.checker = const TraceChecker(),
  });

  final String char;
  final bool freehand;
  final bool enabled;
  final TraceDone onDone;
  final TraceChecker checker;

  /// Tries per stroke in guided mode before the pad draws it and moves on.
  static const int triesPerStroke = 3;

  @override
  State<TracePad> createState() => _TracePadState();
}

class _TracePadState extends State<TracePad> {
  final List<List<Offset>> _ink = [];
  List<Offset>? _current;
  int _stroke = 0;
  int _tries = 0;
  int _skipped = 0;
  final List<double> _scores = [];
  bool _done = false;
  String _hint = '';
  LetterResult? _freehandResult;

  List<List<Offset>> get _target => StrokeData.of(widget.char) ?? const [];

  Offset _toBox(Offset local, double side) =>
      Offset(local.dx / side * StrokeData.box, local.dy / side * StrokeData.box);

  void _start(Offset p, double side) {
    if (_done || !widget.enabled) return;
    setState(() => _current = [_toBox(p, side)]);
  }

  void _move(Offset p, double side) {
    if (_current == null) return;
    setState(() => _current!.add(_toBox(p, side)));
  }

  void _end() {
    final drawn = _current;
    if (drawn == null) return;
    setState(() {
      _current = null;
      if (widget.freehand) {
        _ink.add(drawn);
        return;
      }
      final match = widget.checker.matchStroke(drawn, _target[_stroke]);
      if (match.passed) {
        HapticFeedback.selectionClick();
        _ink.add(_target[_stroke]);
        _scores.add(match.score);
        _advance();
      } else {
        _tries++;
        _hint = !match.rightDirection
            ? 'Start at the dot and follow the arrow.'
            : 'Stay on the line, all the way along.';
        if (_tries >= TracePad.triesPerStroke) {
          _ink.add(_target[_stroke]);
          _scores.add(0);
          _skipped++;
          _hint = 'Here is that stroke. On to the next one.';
          _advance();
        }
      }
    });
  }

  void _advance() {
    _tries = 0;
    _stroke++;
    if (_stroke >= _target.length) {
      _done = true;
      final score = _scores.isEmpty ? 0.0 : _scores.reduce((a, b) => a + b) / _scores.length;
      // One stroke shown after three tries still passes; more does not.
      final passed = _skipped <= 1;
      _hint = passed ? 'Well traced.' : 'Keep practising this letter.';
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone(passed, score));
    } else if (!_hint.startsWith('Here is')) {
      _hint = 'Stroke ${_stroke + 1} of ${_target.length}';
    }
  }

  void _checkFreehand() {
    final result = widget.checker.checkLetter(_ink, _target);
    setState(() {
      _freehandResult = result;
      _done = true;
      _hint = result.passed ? 'That reads as ${widget.char}.' : 'Compare with the letter in blue.';
    });
    widget.onDone(result.passed, result.score);
  }

  void _clear() => setState(() {
        _ink.clear();
        _hint = '';
      });

  @override
  void initState() {
    super.initState();
    _hint = widget.freehand
        ? 'Write the letter from memory.'
        : 'Trace each stroke from the dot.';
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    if (target.isEmpty) return const SizedBox.shrink();
    final dark = AppTokens.isDark(context);
    final showGuide = !widget.freehand || _freehandResult != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.clamp(200.0, 360.0);
        return Column(
          children: [
            Semantics(
              label: widget.freehand
                  ? 'Writing pad for ${widget.char}'
                  : 'Tracing pad for ${widget.char}, stroke ${_stroke + 1} of ${target.length}',
              child: GestureDetector(
                onPanStart: (d) => _start(d.localPosition, side),
                onPanUpdate: (d) => _move(d.localPosition, side),
                onPanEnd: (_) => _end(),
                child: Container(
                  width: side,
                  height: side,
                  decoration: BoxDecoration(
                    color: AppTokens.surface(context),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppTokens.cardBorder(context), width: 2),
                  ),
                  child: CustomPaint(
                    painter: StrokePainter(
                      strokes: _freehandResult != null ? target : const [],
                      guide: showGuide ? target : const [],
                      guideColor: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      inkColor: (dark ? AppColors.primaryNight : AppColors.primary).withValues(alpha: 0.6),
                      ink: [..._ink, if (_current != null) _current!],
                      drawnColor: AppTokens.ink(context),
                      activeStroke: widget.freehand || _done ? null : _stroke,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _hint,
              textAlign: TextAlign.center,
              style: AppTextStyles.poppins(fontSize: 14, color: AppTokens.inkSoft(context)),
            ),
            if (widget.freehand && !_done) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: _ink.isEmpty ? null : _clear, child: const Text('Clear')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _ink.isEmpty || !widget.enabled ? null : _checkFreehand,
                    child: const Text('Check'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
