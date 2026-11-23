/// Drawing a letter's strokes: the stroke-order animation on the character
/// sheet, and the guide and ink of the tracing pad.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/script/stroke_data.dart';
import '../../theme/app_tokens.dart';
import '../../theme/motion.dart';

/// Paints strokes (in the 100 x 100 box) scaled to the canvas.
class StrokePainter extends CustomPainter {
  StrokePainter({
    required this.strokes,
    this.progress = 1,
    this.guide = const [],
    this.guideColor = const Color(0x22000000),
    this.inkColor = AppColors.primary,
    this.ink = const [],
    this.drawnColor = AppColors.inkLight,
    this.activeStroke,
    this.activeColor = AppColors.orange,
    this.width = 7,
  });

  /// Strokes drawn in [inkColor], revealed up to [progress] (0-1 over all).
  final List<List<Offset>> strokes;
  final double progress;

  /// Strokes drawn thick and faint underneath, as the outline to trace.
  final List<List<Offset>> guide;
  final Color guideColor;
  final Color inkColor;

  /// What the learner drew, in box units.
  final List<List<Offset>> ink;
  final Color drawnColor;

  /// Index into [guide] to emphasise, with its start dot.
  final int? activeStroke;
  final Color activeColor;
  final double width;

  Offset _scale(Offset p, Size size) =>
      Offset(p.dx / StrokeData.box * size.width, p.dy / StrokeData.box * size.height);

  Path _path(List<Offset> pts, Size size) {
    final path = Path();
    if (pts.isEmpty) return path;
    final first = _scale(pts.first, size);
    path.moveTo(first.dx, first.dy);
    for (final p in pts.skip(1)) {
      final s = _scale(p, size);
      path.lineTo(s.dx, s.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / StrokeData.box;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final s in guide) {
      canvas.drawPath(_path(s, size), stroke(guideColor, width * 2.2));
    }
    final active = activeStroke;
    if (active != null && active < guide.length) {
      final s = guide[active];
      canvas.drawPath(_path(s, size), stroke(activeColor.withValues(alpha: 0.45), width * 1.2));
      canvas.drawCircle(_scale(s.first, size), width * 1.1 * unit, Paint()..color = activeColor);
      if (s.length >= 2) _arrow(canvas, size, s, unit);
    }

    // Reveal strokes one after another, each along its length.
    final total = strokes.length;
    for (var i = 0; i < total; i++) {
      final share = (progress * total - i).clamp(0.0, 1.0);
      if (share <= 0) break;
      final path = _path(strokes[i], size);
      final metrics = path.computeMetrics().toList();
      for (final ui.PathMetric m in metrics) {
        canvas.drawPath(m.extractPath(0, m.length * share), stroke(inkColor, width));
      }
    }
    for (final s in ink) {
      canvas.drawPath(_path(s, size), stroke(drawnColor, width * 0.8));
    }
  }

  void _arrow(Canvas canvas, Size size, List<Offset> s, double unit) {
    final a = _scale(s[s.length - 2], size), b = _scale(s.last, size);
    final dir = b - a;
    if (dir.distance == 0) return;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final tip = b;
    final back = tip - u * 4 * unit;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((back + n * 2.5 * unit).dx, (back + n * 2.5 * unit).dy)
      ..lineTo((back - n * 2.5 * unit).dx, (back - n * 2.5 * unit).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = activeColor);
  }

  @override
  bool shouldRepaint(StrokePainter old) => true;
}

/// A letter drawing itself stroke by stroke. Plays once; tap to replay.
/// Without motion it shows the finished letter.
class StrokeAnimation extends StatefulWidget {
  const StrokeAnimation({super.key, required this.char, this.size = 180});

  final String char;
  final double size;

  @override
  State<StrokeAnimation> createState() => _StrokeAnimationState();
}

class _StrokeAnimationState extends State<StrokeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final strokes = StrokeData.of(widget.char) ?? const [];
    final level = Motion.of(context);
    _c.duration = level.scale(Duration(milliseconds: 700 * strokes.length));
    if (!level.animates) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _replay() {
    if (!Motion.read(context).animates) return;
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final strokes = StrokeData.of(widget.char);
    if (strokes == null) return const SizedBox.shrink();
    final dark = AppTokens.isDark(context);
    return Semantics(
      label: 'How to write ${widget.char}, ${strokes.length} strokes. Tap to replay.',
      button: true,
      child: GestureDetector(
        onTap: _replay,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppTokens.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTokens.cardBorder(context)),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: StrokePainter(
                strokes: strokes,
                progress: Curves.easeInOut.transform(_c.value),
                guide: strokes,
                guideColor: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                inkColor: dark ? AppColors.primaryNight : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
