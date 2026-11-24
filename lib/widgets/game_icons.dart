/// Line icons for the games, drawn in code at one stroke weight: a conch
/// for listening, a prayer wheel for speed, a Tibetan letter on the
/// flashcard.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tibetan_type.dart';

enum GameGlyph {
  conch,
  picture,
  pairs,
  trueFalse,
  syllables,
  flashcard,
  tiles,
  prayerWheel,
}

class GameIcon extends StatelessWidget {
  const GameIcon(this.glyph, {super.key, required this.color, this.size = 28});

  final GameGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: RepaintBoundary(
          child: CustomPaint(painter: GameIconPainter(glyph, color)),
        ),
      ),
    );
  }
}

class GameIconPainter extends CustomPainter {
  const GameIconPainter(this.glyph, this.color);

  final GameGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset o(double x, double y) => Offset(x * s, y * s);
    final line =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.6, s * 0.075)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    RRect box(double l, double t, double r, double b, [double rad = 0.08]) =>
        RRect.fromLTRBR(l * s, t * s, r * s, b * s, Radius.circular(rad * s));

    switch (glyph) {
      case GameGlyph.conch:
        // A dungkar, the white conch: pointed spire, swelling whorl, the
        // long siphon below, and its sound to the right.
        final shell =
            Path()
              ..moveTo(0.14 * s, 0.12 * s)
              ..cubicTo(
                0.46 * s,
                0.14 * s,
                0.7 * s,
                0.26 * s,
                0.66 * s,
                0.5 * s,
              )
              ..cubicTo(0.64 * s, 0.62 * s, 0.54 * s, 0.7 * s, 0.5 * s, 0.9 * s)
              ..cubicTo(0.4 * s, 0.72 * s, 0.24 * s, 0.6 * s, 0.2 * s, 0.44 * s)
              ..cubicTo(
                0.17 * s,
                0.32 * s,
                0.14 * s,
                0.22 * s,
                0.14 * s,
                0.12 * s,
              )
              ..close();
        canvas.drawPath(shell, line);
        canvas.drawPath(
          Path()
            ..moveTo(0.2 * s, 0.3 * s)
            ..quadraticBezierTo(0.4 * s, 0.26 * s, 0.56 * s, 0.34 * s),
          line,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.24 * s, 0.48 * s)
            ..quadraticBezierTo(0.44 * s, 0.44 * s, 0.64 * s, 0.52 * s),
          line,
        );
        for (final r in [0.12, 0.24]) {
          canvas.drawArc(
            Rect.fromCircle(center: o(0.68, 0.7), radius: r * s),
            -0.9,
            1.3,
            false,
            line,
          );
        }
      case GameGlyph.picture:
        canvas.drawRRect(box(0.1, 0.16, 0.9, 0.84, 0.1), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.2 * s, 0.72 * s)
            ..lineTo(0.42 * s, 0.42 * s)
            ..lineTo(0.54 * s, 0.56 * s)
            ..lineTo(0.64 * s, 0.46 * s)
            ..lineTo(0.8 * s, 0.72 * s),
          line,
        );
        canvas.drawCircle(o(0.7, 0.32), 0.06 * s, fill);
      case GameGlyph.pairs:
        canvas.drawRRect(box(0.08, 0.1, 0.44, 0.46), line);
        canvas.drawRRect(box(0.56, 0.54, 0.92, 0.9), line);
        canvas.drawPath(
          Path()
            ..moveTo(0.44 * s, 0.28 * s)
            ..cubicTo(
              0.72 * s,
              0.28 * s,
              0.28 * s,
              0.72 * s,
              0.56 * s,
              0.72 * s,
            ),
          line,
        );
        canvas.drawCircle(o(0.26, 0.28), 0.06 * s, fill);
        canvas.drawCircle(o(0.74, 0.72), 0.06 * s, fill);
      case GameGlyph.trueFalse:
        canvas.drawPath(
          Path()
            ..moveTo(0.08 * s, 0.52 * s)
            ..lineTo(0.24 * s, 0.68 * s)
            ..lineTo(0.46 * s, 0.32 * s),
          line,
        );
        canvas.drawLine(o(0.6, 0.36), o(0.88, 0.64), line);
        canvas.drawLine(o(0.88, 0.36), o(0.6, 0.64), line);
      case GameGlyph.syllables:
        // Syllable blocks with a tsheg between them.
        for (final (l, r) in [(0.06, 0.32), (0.4, 0.66)]) {
          canvas.drawRRect(box(l, 0.4, r, 0.76, 0.06), line);
          canvas.drawCircle(o(r + 0.04, 0.44), 0.035 * s, fill);
        }
        canvas.drawRRect(box(0.74, 0.18, 0.96, 0.5, 0.06), line);
        canvas.drawLine(o(0.85, 0.56), o(0.85, 0.76), line);
      case GameGlyph.flashcard:
        canvas.save();
        canvas.translate(0.56 * s, 0.5 * s);
        canvas.rotate(0.22);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: 0.5 * s,
              height: 0.66 * s,
            ),
            Radius.circular(0.08 * s),
          ),
          line,
        );
        canvas.restore();
        final front = box(0.1, 0.18, 0.58, 0.86);
        canvas.drawRRect(front, Paint()..color = color.withValues(alpha: 0.14));
        canvas.drawRRect(front, line);
        final tp = TextPainter(
          text: TextSpan(
            text: 'ཀ',
            style: TextStyle(
              fontFamily: TibetanType.family,
              fontSize: s * 0.36,
              color: color,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(0.34 * s - tp.width / 2, 0.52 * s - tp.height / 2),
        );
        tp.dispose();
      case GameGlyph.tiles:
        for (final (x, y, open) in [
          (0.08, 0.08, false),
          (0.54, 0.08, true),
          (0.08, 0.54, true),
          (0.54, 0.54, false),
        ]) {
          final r = box(x, y, x + 0.38, y + 0.38);
          if (open) {
            canvas.drawRRect(r, line);
            canvas.drawCircle(r.center, 0.07 * s, fill);
          } else {
            canvas.drawRRect(r, fill);
          }
        }
      case GameGlyph.prayerWheel:
        // A hand prayer wheel turning: drum on its handle, the weight on
        // its chain, and the sweep of the spin.
        canvas.drawRRect(box(0.32, 0.2, 0.66, 0.56, 0.06), line);
        canvas.drawLine(o(0.32, 0.32), o(0.66, 0.32), line);
        canvas.drawLine(o(0.32, 0.44), o(0.66, 0.44), line);
        canvas.drawCircle(o(0.49, 0.12), 0.045 * s, fill);
        canvas.drawLine(o(0.49, 0.56), o(0.49, 0.94), line);
        canvas.drawLine(o(0.66, 0.36), o(0.82, 0.46), line);
        canvas.drawCircle(o(0.86, 0.5), 0.065 * s, fill);
        canvas.drawArc(
          Rect.fromCircle(center: o(0.49, 0.38), radius: 0.34 * s),
          math.pi * 0.62,
          math.pi * 0.62,
          false,
          line,
        );
    }
  }

  @override
  bool shouldRepaint(GameIconPainter old) =>
      old.glyph != glyph || old.color != color;
}
