/// The one landmark each unit is built around, drawn with more care than
/// the small props: lit on the side facing the sun, shaded on the other,
/// casting a shadow on the ground away from the light.
///
/// [b] is the bottom centre where the landmark meets the ground and [s]
/// its scale (1 is about 60 px tall for a chorten).
library;

import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'biome.dart';
import 'paint_kit.dart';
import 'props.dart';

const Color _gold = Color(0xFFE2A93A);
const Color _goldDeep = Color(0xFFA9741F);

/// A shadow laid on the ground, stretched away from the light.
void castShadow(Canvas c, Offset b, double w, BiomePalette p, {double k = 1}) {
  final dir = p.lightFromLeft ? 1.0 : -1.0;
  final len = w * (0.5 + 0.5 * (1 - (p.sunAt.dy).clamp(0.0, 1.0))) * k;
  c.drawOval(
    Rect.fromLTRB(
      math.min(b.dx - w * 0.45, b.dx + dir * len),
      b.dy - w * 0.05,
      math.max(b.dx + w * 0.45, b.dx + dir * len),
      b.dy + w * 0.07,
    ).shift(Offset(dir * w * 0.12, 0)),
    fillPaint(
      (p.dark ? const Color(0xFF000814) : const Color(0xFF2E2A1E)).withValues(
        alpha: p.dark ? 0.32 : 0.16,
      ),
    ),
  );
}

/// Shading across a form: the lit colour on the sun side, the shade on
/// the other.
Paint across(Rect r, Color lit, Color shade, BiomePalette p) {
  final a = p.lightFromLeft ? r.centerLeft : r.centerRight;
  final b = p.lightFromLeft ? r.centerRight : r.centerLeft;
  return Paint()
    ..shader = ui.Gradient.linear(
      a,
      b,
      [lit, lit, shade],
      const [0, 0.42, 0.75],
    );
}

Color _shadeOf(Color c, BiomePalette p, [double k = 0.5]) =>
    Color.lerp(c, p.rockShade, k)!;

/// The valley's chorten: three stepped plinths, a whitewashed dome, the
/// thirteen gold rings of the spire, a parasol and the sun and moon.
void drawChortenHero(Canvas c, Offset b, double s, BiomePalette p) {
  castShadow(c, b, 64 * s, p, k: 1.2);
  final white = p.wall;
  final shade = _shadeOf(white, p, p.dark ? 0.45 : 0.32);
  var y = b.dy;
  for (final (w, h) in [(52.0, 7.0), (42.0, 6.0), (34.0, 6.0)]) {
    final r = Rect.fromLTWH(b.dx - w * s / 2, y - h * s, w * s, h * s);
    c.drawRect(r, across(r, white, shade, p));
    // The lip at the top of each step catches the light.
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 1.2 * s),
      fillPaint(Color.lerp(white, p.light, 0.6)!),
    );
    y -= h * s;
  }
  // The dome (bumpa), wider at the shoulder.
  final dome =
      Path()
        ..moveTo(b.dx - 13 * s, y)
        ..cubicTo(
          b.dx - 17 * s,
          y - 10 * s,
          b.dx - 14 * s,
          y - 20 * s,
          b.dx - 8 * s,
          y - 20 * s,
        )
        ..lineTo(b.dx + 8 * s, y - 20 * s)
        ..cubicTo(
          b.dx + 14 * s,
          y - 20 * s,
          b.dx + 17 * s,
          y - 10 * s,
          b.dx + 13 * s,
          y,
        )
        ..close();
  final domeRect = Rect.fromLTRB(b.dx - 17 * s, y - 20 * s, b.dx + 17 * s, y);
  c.drawPath(dome, across(domeRect, white, shade, p));
  y -= 20 * s;
  // Harmika: the box above the dome, with the painted eyes' frame.
  final harmika = Rect.fromLTWH(b.dx - 7 * s, y - 6 * s, 14 * s, 6 * s);
  c.drawRect(harmika, across(harmika, white, shade, p));
  y -= 6 * s;
  // Spire of thirteen rings.
  final gold = p.tone(_gold, 0.3);
  final goldShade = p.tone(_goldDeep, 0.35);
  final spireRect = Rect.fromLTRB(
    b.dx - 4.5 * s,
    y - 20 * s,
    b.dx + 4.5 * s,
    y,
  );
  final spire =
      Path()
        ..moveTo(b.dx - 4.5 * s, y)
        ..lineTo(b.dx + 4.5 * s, y)
        ..lineTo(b.dx + 1.6 * s, y - 20 * s)
        ..lineTo(b.dx - 1.6 * s, y - 20 * s)
        ..close();
  c.drawPath(spire, across(spireRect, gold, goldShade, p));
  final ring =
      Paint()
        ..color = goldShade.withValues(alpha: 0.8)
        ..strokeWidth = 0.6 * s;
  for (var i = 1; i < 13; i++) {
    final yy = y - i * 1.55 * s;
    final half = 4.5 * s - (4.5 - 1.6) * s * (i / 13);
    c.drawLine(Offset(b.dx - half, yy), Offset(b.dx + half, yy), ring);
  }
  y -= 20 * s;
  // Parasol.
  c.drawPath(
    Path()
      ..moveTo(b.dx - 5 * s, y + 0.5 * s)
      ..quadraticBezierTo(b.dx, y - 3.5 * s, b.dx + 5 * s, y + 0.5 * s)
      ..close(),
    fillPaint(gold),
  );
  // Moon and sun.
  c.drawArc(
    Rect.fromCircle(center: Offset(b.dx, y - 3 * s), radius: 2.6 * s),
    math.pi * 0.05,
    math.pi * 0.9,
    false,
    Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s,
  );
  c.drawCircle(Offset(b.dx, y - 5.6 * s), 1.6 * s, fillPaint(gold));
}

/// A black yak-hair tent: low and wide, a raised ridge with the smoke
/// slit, guy ropes out to the pegs, a lighter woven top where the sun
/// falls.
void drawTentHero(Canvas c, Offset b, double s, BiomePalette p) {
  final w = 58 * s, h = 24 * s;
  castShadow(c, b, w * 1.1, p);
  final rope =
      Paint()
        ..color = p.tone(const Color(0xFF5E4C3B), 0.5).withValues(alpha: 0.9)
        ..strokeWidth = 0.8 * s;
  for (final side in [-1.0, 1.0]) {
    for (final (from, to) in [(0.28, 0.9), (0.42, 1.02)]) {
      c.drawLine(
        Offset(b.dx + side * w * from, b.dy - h * 0.92),
        Offset(b.dx + side * w * to, b.dy),
        rope,
      );
    }
  }
  final body =
      Path()
        ..moveTo(b.dx - w / 2, b.dy)
        ..lineTo(b.dx - w * 0.4, b.dy - h * 0.78)
        ..lineTo(b.dx - w * 0.1, b.dy - h)
        ..lineTo(b.dx - w * 0.03, b.dy - h * 1.14)
        ..lineTo(b.dx + w * 0.03, b.dy - h * 1.14)
        ..lineTo(b.dx + w * 0.1, b.dy - h)
        ..lineTo(b.dx + w * 0.4, b.dy - h * 0.78)
        ..lineTo(b.dx + w / 2, b.dy)
        ..close();
  final black = p.dark ? const Color(0xFF0E0C0B) : const Color(0xFF2A221D);
  final lit = p.dark ? const Color(0xFF2A2C3A) : const Color(0xFF4F433A);
  final rect = Rect.fromLTRB(b.dx - w / 2, b.dy - h * 1.14, b.dx + w / 2, b.dy);
  c.drawPath(body, across(rect, lit, black, p));
  // The roof catches more light than the walls.
  c.save();
  c.clipPath(body);
  c.drawRect(
    Rect.fromLTRB(rect.left, rect.top, rect.right, b.dy - h * 0.72),
    fillPaint(
      (p.dark ? const Color(0xFF9FB0D8) : const Color(0xFFFFF2DC)).withValues(
        alpha: p.dark ? 0.08 : 0.12,
      ),
    ),
  );
  // Woven strips.
  final strip =
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.22)
        ..strokeWidth = 0.9 * s;
  for (var i = -3; i <= 3; i++) {
    c.drawLine(
      Offset(b.dx + i * w * 0.11, b.dy - h * 1.05),
      Offset(b.dx + i * w * 0.15, b.dy),
      strip,
    );
  }
  c.restore();
  // The door: dark by day, firelight by night.
  final door =
      Path()
        ..moveTo(b.dx - 6 * s, b.dy)
        ..lineTo(b.dx - 1 * s, b.dy - 13 * s)
        ..lineTo(b.dx + 1 * s, b.dy - 13 * s)
        ..lineTo(b.dx + 6 * s, b.dy)
        ..close();
  if (p.dark) {
    c.drawCircle(
      b.translate(0, -5 * s),
      18 * s,
      Paint()
        ..shader = ui.Gradient.radial(b.translate(0, -5 * s), 18 * s, [
          const Color(0xFFF6B44C).withValues(alpha: 0.35),
          const Color(0x00F6B44C),
        ]),
    );
  }
  c.drawPath(
    door,
    fillPaint(p.dark ? const Color(0xFFF6BA55) : const Color(0xFF7A5C40)),
  );
  // Smoke from the slit, thinning as it rises.
  final top = b.translate(0, -h * 1.16);
  for (var i = 0; i < 3; i++) {
    final t = i / 3;
    c.drawPath(
      Path()
        ..moveTo(top.dx + (i - 1) * 1.2 * s, top.dy - t * 9 * s)
        ..cubicTo(
          top.dx - 6 * s,
          top.dy - (8 + t * 8) * s,
          top.dx + 8 * s,
          top.dy - (14 + t * 10) * s,
          top.dx + (3 + t * 6) * s,
          top.dy - (22 + t * 12) * s,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (3.2 - i) * s
        ..color = (p.dark ? const Color(0xFF8E9CC0) : const Color(0xFFFFFFFF))
            .withValues(alpha: 0.5 - i * 0.12),
    );
  }
}

/// A fir of the Kham forests: a narrow spire of drooping tiers, lit on the
/// sun side.
void drawFirHero(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  int seed = 0,
  double tone = 0,
}) {
  final r = math.Random(seed);
  final h = 120 * s;
  final w = 34 * s;
  final dark = p.tone(
    Color.lerp(const Color(0xFF1E4232), const Color(0xFF28503A), tone)!,
    0.55,
  );
  final lit = p.tone(
    Color.lerp(const Color(0xFF3F7650), const Color(0xFF52875A), tone)!,
    0.55,
  );
  c.drawLine(
    b,
    b.translate(0, -h * 0.14),
    Paint()
      ..color = p.tone(const Color(0xFF4A3426), 0.5)
      ..strokeWidth = 3.2 * s,
  );
  // Edge points of the silhouette, tier by tier.
  final left = <Offset>[];
  final right = <Offset>[];
  const tiers = 9;
  for (var i = 0; i <= tiers; i++) {
    final t = i / tiers;
    final y = b.dy - h * 0.1 - (h * 0.9) * t;
    final half =
        w * 0.5 * math.pow(1 - t, 0.95) * (0.85 + r.nextDouble() * 0.3);
    final droop = 5 * s * (1 - t);
    left
      ..add(Offset(b.dx - half, y + droop))
      ..add(Offset(b.dx - half * 0.45, y - 4 * s));
    right
      ..add(Offset(b.dx + half, y + droop))
      ..add(Offset(b.dx + half * 0.45, y - 4 * s));
  }
  final tip = Offset(b.dx, b.dy - h - 6 * s);
  final shape = Path()..moveTo(left.first.dx, left.first.dy);
  for (final o in left) {
    shape.lineTo(o.dx, o.dy);
  }
  shape.lineTo(tip.dx, tip.dy);
  for (final o in right.reversed) {
    shape.lineTo(o.dx, o.dy);
  }
  shape.close();
  final rect = Rect.fromLTRB(b.dx - w / 2, tip.dy, b.dx + w / 2, b.dy);
  c.drawPath(shape, across(rect, lit, dark, p));
}

/// A whitewashed monastery on its ridge: halls stepping up the slope to
/// a red temple with a brown penbey frieze and a gold roof.
void drawMonasteryHero(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p,
  double Function(double x) groundAt,
) {
  final white = p.wall;
  final whiteShade = _shadeOf(white, p, p.dark ? 0.4 : 0.3);
  final red = p.tone(const Color(0xFF9A2E22), 0.45);
  final redShade = _shadeOf(red, p, 0.35);
  final penbey = p.tone(const Color(0xFF5A2A1E), 0.45);
  final gold = p.tone(_gold, 0.25);
  final goldShade = p.tone(_goldDeep, 0.3);
  final dir = p.lightFromLeft ? -1.0 : 1.0;

  void windows(Rect r, int n, double size) {
    for (var i = 0; i < n; i++) {
      final cx = r.left + r.width * (i + 0.5) / n;
      final cy = r.top + r.height * 0.45;
      final frame = Rect.fromCenter(
        center: Offset(cx, cy),
        width: size * 1.5,
        height: size * 1.6,
      );
      // Black trapezoid frame, wider at the foot, under a red lintel.
      final flare = size * 0.35;
      c.drawPath(
        Path()
          ..moveTo(frame.left - flare, frame.bottom)
          ..lineTo(frame.right + flare, frame.bottom)
          ..lineTo(frame.right, frame.top)
          ..lineTo(frame.left, frame.top)
          ..close(),
        fillPaint(p.frame),
      );
      c.drawRect(
        Rect.fromLTRB(
          frame.left - flare * 0.6,
          frame.top - size * 0.55,
          frame.right + flare * 0.6,
          frame.top - size * 0.1,
        ),
        fillPaint(p.tone(const Color(0xFFB8342A), 0.45)),
      );
      final glass = frame.deflate(size * 0.3);
      if (p.dark) {
        c.drawCircle(
          glass.center,
          size * 2.2,
          Paint()
            ..shader = ui.Gradient.radial(glass.center, size * 2.2, [
              p.window.withValues(alpha: 0.35),
              p.window.withValues(alpha: 0),
            ]),
        );
      }
      c.drawRect(glass, fillPaint(p.window));
    }
  }

  // A tapering block set into the hill: its walls run down past the
  // slope so nothing floats, a penbey band along its roof.
  void block(
    double cx,
    double bottom,
    double bw,
    double bh,
    Color face,
    Color faceShade, {
    double band = 2.6,
  }) {
    final depth = 14 * s;
    final t = bw * 0.05;
    final r = Rect.fromLTRB(
      cx - bw / 2,
      bottom - bh,
      cx + bw / 2,
      bottom + depth,
    );
    final wall =
        Path()
          ..moveTo(r.left, r.bottom)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.right - t, r.top)
          ..lineTo(r.left + t, r.top)
          ..close();
    c.drawPath(wall, across(r, face, faceShade, p));
    c.drawRect(
      Rect.fromLTWH(
        r.left + t - 0.8 * s,
        r.top - band * s,
        r.width - 2 * t + 1.6 * s,
        band * s + 0.4 * s,
      ),
      fillPaint(penbey),
    );
  }

  // Halls stepping down the slope on the side away from the light.
  for (var i = 4; i >= 1; i--) {
    final x = b.dx + dir * i * 18 * s;
    final y = groundAt(x) + 2 * s;
    final hw = (21 - i * 1.0) * s, hh = (15 - i * 0.6) * s;
    block(x, y, hw, hh, white, whiteShade);
    windows(
      Rect.fromLTRB(
        x - hw / 2 + 3 * s,
        y - hh + 2.5 * s,
        x + hw / 2 - 3 * s,
        y - 4 * s,
      ),
      2,
      2.1 * s,
    );
  }
  // The great hall's whitewashed base, two rows of windows.
  final base = Rect.fromLTWH(b.dx - 27 * s, b.dy - 18 * s, 54 * s, 22 * s);
  block(b.dx, base.bottom, base.width, base.height, white, whiteShade, band: 3);
  windows(
    Rect.fromLTRB(
      base.left + 5 * s,
      base.top + 3 * s,
      base.right - 5 * s,
      base.top + 9 * s,
    ),
    5,
    2.2 * s,
  );
  windows(
    Rect.fromLTRB(
      base.left + 5 * s,
      base.top + 11 * s,
      base.right - 5 * s,
      base.top + 17 * s,
    ),
    5,
    2.2 * s,
  );
  // The red temple above it.
  final hall = Rect.fromLTWH(b.dx - 18 * s, base.top - 26 * s, 36 * s, 26 * s);
  c.drawRect(hall, across(hall, red, redShade, p));
  c.drawRect(
    Rect.fromLTWH(hall.left - 1 * s, hall.top, hall.width + 2 * s, 5 * s),
    fillPaint(penbey),
  );
  windows(
    Rect.fromLTRB(
      hall.left + 3 * s,
      hall.top + 7 * s,
      hall.right - 3 * s,
      hall.bottom - 3 * s,
    ),
    3,
    2.8 * s,
  );
  // The gold roof with its pinnacles.
  final roofRect = Rect.fromLTRB(
    hall.left + 4 * s,
    hall.top - 9 * s,
    hall.right - 4 * s,
    hall.top,
  );
  c.drawPath(
    Path()
      ..moveTo(hall.left + 2 * s, hall.top)
      ..lineTo(hall.left + 8 * s, hall.top - 8 * s)
      ..lineTo(hall.right - 8 * s, hall.top - 8 * s)
      ..lineTo(hall.right - 2 * s, hall.top)
      ..close(),
    across(roofRect, gold, goldShade, p),
  );
  // The ganjira, the gold pinnacle vase, on the ridge of the roof.
  final gj = Offset(b.dx, hall.top - 8 * s);
  c.drawPath(
    Path()
      ..moveTo(gj.dx - 3 * s, gj.dy)
      ..lineTo(gj.dx + 3 * s, gj.dy)
      ..quadraticBezierTo(
        gj.dx + 4.2 * s,
        gj.dy - 4 * s,
        gj.dx + 1.2 * s,
        gj.dy - 6 * s,
      )
      ..lineTo(gj.dx + 0.8 * s, gj.dy - 10 * s)
      ..lineTo(gj.dx - 0.8 * s, gj.dy - 10 * s)
      ..lineTo(gj.dx - 1.2 * s, gj.dy - 6 * s)
      ..quadraticBezierTo(gj.dx - 4.2 * s, gj.dy - 4 * s, gj.dx - 3 * s, gj.dy)
      ..close(),
    across(
      Rect.fromLTRB(gj.dx - 4 * s, gj.dy - 10 * s, gj.dx + 4 * s, gj.dy),
      gold,
      goldShade,
      p,
    ),
  );
  c.drawCircle(gj.translate(0, -11 * s), 1.3 * s, fillPaint(gold));
  // The dharma wheel and its deer above the hall's front.
  drawDharmaWheel(c, Offset(b.dx, hall.top + 0.5 * s), s * 0.85, p);
  // Two victory banners on the roof corners.
  for (final x in [hall.left + 1 * s, hall.right - 1 * s]) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 1.8 * s, hall.top - 9 * s, x + 1.8 * s, hall.top),
        Radius.circular(1.6 * s),
      ),
      fillPaint(p.tone(const Color(0xFF2E2520), 0.4)),
    );
    c.drawCircle(Offset(x, hall.top - 9.6 * s), 1.4 * s, fillPaint(gold));
  }
}

/// A lhatse on the pass: a cairn bristling with sticks, flag strings
/// fanning down to the ground on both sides, a khata tied round it.
void drawLhatseHero(Canvas c, Offset b, double s, BiomePalette p) {
  final top = b.translate(0, -34 * s);
  for (final (dx, dy, sag) in [
    (-70.0, 6.0, 8.0),
    (-44.0, 2.0, 5.0),
    (46.0, 3.0, 6.0),
    (74.0, 8.0, 9.0),
  ]) {
    drawFlagString(
      c,
      top.translate(0, 3 * s),
      b.translate(dx * s, dy * s),
      sag * s,
      p,
      size: s * 0.95,
    );
  }
  castShadow(c, b, 44 * s, p);
  final stone = p.tone(const Color(0xFF9A958C), 0.55);
  final cairn =
      Path()
        ..moveTo(b.dx - 19 * s, b.dy)
        ..quadraticBezierTo(
          b.dx - 15 * s,
          b.dy - 20 * s,
          b.dx - 4 * s,
          b.dy - 27 * s,
        )
        ..lineTo(b.dx + 4 * s, b.dy - 27 * s)
        ..quadraticBezierTo(b.dx + 15 * s, b.dy - 20 * s, b.dx + 19 * s, b.dy)
        ..close();
  final rect = Rect.fromLTRB(b.dx - 19 * s, b.dy - 27 * s, b.dx + 19 * s, b.dy);
  c.drawPath(cairn, across(rect, stone, _shadeOf(stone, p, 0.5), p));
  final r = math.Random(7);
  for (var i = 0; i < 12; i++) {
    final o = b.translate(
      (r.nextDouble() - 0.5) * 28 * s,
      -(3 + r.nextDouble() * 20) * s,
    );
    c.drawOval(
      Rect.fromCenter(center: o, width: 7 * s, height: 4.4 * s),
      fillPaint(
        p
            .tone(
              i.isEven ? const Color(0xFFBDB8AE) : const Color(0xFF6E6A63),
              0.55,
            )
            .withValues(alpha: 0.9),
      ),
    );
  }
  // Snow on the cairn's lit shoulder.
  c.drawPath(
    Path()
      ..moveTo(b.dx - 4 * s, b.dy - 27 * s)
      ..lineTo(b.dx + 4 * s, b.dy - 27 * s)
      ..quadraticBezierTo(
        b.dx + 8 * s,
        b.dy - 24 * s,
        b.dx + 7 * s,
        b.dy - 22 * s,
      )
      ..quadraticBezierTo(b.dx, b.dy - 24 * s, b.dx - 8 * s, b.dy - 22 * s)
      ..close(),
    fillPaint(p.light),
  );
  final stick =
      Paint()
        ..color = p.tone(const Color(0xFF6B5136), 0.5)
        ..strokeWidth = 1.2 * s
        ..strokeCap = StrokeCap.round;
  for (final a in [-0.4, -0.15, 0.1, 0.35]) {
    c.drawLine(
      top.translate(0, 8 * s),
      top.translate(math.sin(a) * 14 * s, -math.cos(a) * 9 * s),
      stick,
    );
  }
  c.drawLine(
    b.translate(-12 * s, -15 * s),
    b.translate(12 * s, -17 * s),
    Paint()
      ..color = p.tone(const Color(0xFFFFFFFF), 0.3)
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round,
  );
}

/// A whitewashed Tibetan home in three-quarter view: walls that taper as
/// they rise, a shaded side wall, the dark penbey band under a flat roof,
/// black trapezoid window frames under red lintels, a maroon door, and a
/// prayer-flag pole at each front corner of the roof with its five
/// colours and a juniper sprig on top. [floors] is 1 or 2.
void drawTibetanHome(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  bool flip = false,
  int floors = 2,
}) {
  final w = (floors == 2 ? 54.0 : 46.0) * s;
  final h = (floors == 2 ? 38.0 : 24.0) * s;
  final taper = 3.2 * s;
  final side = 11 * s;
  // The side wall shows on the side away from the light.
  final dir = p.lightFromLeft ? 1.0 : -1.0;
  final front = b.translate(-dir * side / 2, 0);
  castShadow(c, b, w * 1.15, p);
  final white = p.wall;
  final shade = _shadeOf(white, p, p.dark ? 0.45 : 0.36);
  final l = front.dx - w / 2, r = front.dx + w / 2, top = b.dy - h;

  // Side wall, receding.
  final edge = dir > 0 ? r : l;
  final sidePath =
      Path()
        ..moveTo(edge, b.dy)
        ..lineTo(edge + dir * side, b.dy - 4 * s)
        ..lineTo(edge + dir * (side - taper), top - 3 * s)
        ..lineTo(edge - dir * taper, top)
        ..close();
  c.drawPath(sidePath, fillPaint(shade));
  // Front wall.
  final wall =
      Path()
        ..moveTo(l, b.dy)
        ..lineTo(r, b.dy)
        ..lineTo(r - taper, top)
        ..lineTo(l + taper, top)
        ..close();
  final wallRect = Rect.fromLTRB(l, top, r, b.dy);
  c.drawPath(
    wall,
    vertical(wallRect, [
      Color.lerp(white, p.light, 0.4)!,
      white,
      Color.lerp(white, shade, 0.35)!,
    ]),
  );
  // The penbey band and the flat roof.
  final penbey = p.tone(const Color(0xFF5B2A1F), 0.45);
  final band = Rect.fromLTRB(
    l + taper - 1.5 * s,
    top - 4.5 * s,
    r - taper + 1.5 * s,
    top + 0.5 * s,
  );
  c.drawRect(band, fillPaint(penbey));
  final twig =
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.25)
        ..strokeWidth = 0.6 * s;
  for (var x = band.left + 1.5 * s; x < band.right; x += 1.6 * s) {
    c.drawLine(
      Offset(x, band.top + 1 * s),
      Offset(x, band.bottom - 1 * s),
      twig,
    );
  }
  c.drawPath(
    Path()
      ..moveTo(edge - dir * (taper - 1.5 * s), band.top)
      ..lineTo(edge + dir * (side - taper + 1 * s), band.top - 3 * s)
      ..lineTo(edge + dir * (side - taper + 1 * s), band.bottom - 3 * s)
      ..lineTo(edge - dir * (taper - 1.5 * s), band.bottom)
      ..close(),
    fillPaint(Color.lerp(penbey, const Color(0xFF000000), 0.25)!),
  );
  c.drawRect(
    Rect.fromLTRB(band.left, band.top - 1.2 * s, band.right, band.top),
    fillPaint(Color.lerp(white, p.light, 0.3)!),
  );

  final lintel = p.tone(const Color(0xFFB8342A), 0.45);
  void window(double cx, double wy, double ww, double wh) {
    final frame =
        Path()
          ..moveTo(cx - ww / 2 - 2.4 * s, wy + wh)
          ..lineTo(cx + ww / 2 + 2.4 * s, wy + wh)
          ..lineTo(cx + ww / 2 + 0.6 * s, wy)
          ..lineTo(cx - ww / 2 - 0.6 * s, wy)
          ..close();
    c.drawPath(frame, fillPaint(p.frame));
    final glass = Rect.fromLTWH(
      cx - ww / 2 + 0.7 * s,
      wy + 1.3 * s,
      ww - 1.4 * s,
      wh - 2.6 * s,
    );
    if (p.dark) {
      c.drawCircle(
        glass.center,
        ww * 1.6,
        Paint()
          ..shader = ui.Gradient.radial(glass.center, ww * 1.6, [
            p.window.withValues(alpha: 0.32),
            p.window.withValues(alpha: 0),
          ]),
      );
    }
    c.drawRect(glass, fillPaint(p.window));
    // Mullion.
    c.drawLine(
      Offset(cx, glass.top),
      Offset(cx, glass.bottom),
      Paint()
        ..color = p.frame
        ..strokeWidth = 0.7 * s,
    );
    // The red lintel with its little frill.
    final lt = Rect.fromLTWH(
      cx - ww / 2 - 1.8 * s,
      wy - 2.6 * s,
      ww + 3.6 * s,
      2 * s,
    );
    c.drawRect(lt, fillPaint(lintel));
    c.drawRect(
      Rect.fromLTWH(lt.left + 0.6 * s, lt.bottom, lt.width - 1.2 * s, 0.9 * s),
      fillPaint(p.tone(const Color(0xFF2174C8), 0.45)),
    );
  }

  final ww = 6.2 * s, wh = 7.2 * s;
  if (floors == 2) {
    for (final t in [-0.3, 0.0, 0.3]) {
      window(front.dx + t * w, top + 6 * s, ww, wh);
    }
  }
  final groundRow = b.dy - (floors == 2 ? 15 : 14) * s;
  final doorX = front.dx + (flip ? -0.24 : 0.24) * w;
  window(front.dx - (flip ? -0.2 : 0.2) * w, groundRow, ww, wh);
  // Door: black frame, maroon leaves, a gold ring.
  final door = Rect.fromLTWH(doorX - 4.6 * s, b.dy - 13 * s, 9.2 * s, 13 * s);
  c.drawPath(
    Path()
      ..moveTo(door.left - 1.6 * s, door.bottom)
      ..lineTo(door.right + 1.6 * s, door.bottom)
      ..lineTo(door.right + 0.4 * s, door.top)
      ..lineTo(door.left - 0.4 * s, door.top)
      ..close(),
    fillPaint(p.frame),
  );
  c.drawRect(
    door.deflate(1.3 * s).translate(0, 0.6 * s),
    fillPaint(p.tone(const Color(0xFF7E2A1F), 0.5)),
  );
  c.drawCircle(
    door.center.translate(0, 1 * s),
    0.9 * s,
    fillPaint(p.tone(_gold, 0.3)),
  );
  c.drawRect(
    Rect.fromLTWH(
      door.left - 2 * s,
      door.top - 2.6 * s,
      door.width + 4 * s,
      2 * s,
    ),
    fillPaint(lintel),
  );

  // Prayer-flag poles at the front corners of the roof.
  for (final x in [band.left + 1 * s, band.right - 1 * s]) {
    final foot = Offset(x, band.top - 1 * s);
    final tip = foot.translate(0, -20 * s);
    c.drawLine(
      foot,
      tip,
      Paint()
        ..color = p.tone(const Color(0xFF5E4630), 0.5)
        ..strokeWidth = 1.1 * s
        ..strokeCap = StrokeCap.round,
    );
    final away = x < front.dx ? -1.0 : 1.0;
    for (var i = 0; i < 5; i++) {
      c.drawRect(
        Rect.fromLTWH(
          away > 0 ? x + 0.5 * s : x - 4.7 * s,
          tip.dy + 2.5 * s + i * 2.6 * s,
          4.2 * s,
          2.6 * s,
        ),
        fillPaint(p.tone(kLungtaColors[i], 0.4)),
      );
    }
    c.drawCircle(tip, 1.5 * s, fillPaint(p.tone(const Color(0xFF2F5B3A), 0.5)));
  }
}

/// The coats a yak can wear.
enum YakCoat { black, pied, white }

/// A yak: a high hump over the shoulders, a long skirt of hair almost to
/// the ground, a bushy tail, pale horns curving up. [grazing] puts the
/// head down to the grass. [facing] is 1 (right) or -1 (left).
void drawYakHero(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  double facing = 1,
  YakCoat coat = YakCoat.black,
  bool grazing = false,
}) {
  castShadow(c, b, 40 * s, p, k: 0.6);
  c.save();
  c.translate(b.dx, b.dy);
  c.scale(facing * s, s);
  final body = switch (coat) {
    YakCoat.white => p.tone(const Color(0xFFEDE5D8), 0.45),
    _ => p.dark ? const Color(0xFF0F0D0C) : const Color(0xFF241D19),
  };
  final hair = switch (coat) {
    YakCoat.white => p.tone(const Color(0xFFCBBFAD), 0.45),
    _ => p.dark ? const Color(0xFF060505) : const Color(0xFF15110F),
  };
  final paint = fillPaint(body);
  // Legs under the skirt.
  final leg =
      Paint()
        ..color = hair
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round;
  for (final x in [-13.0, -8.5, 8.5, 12.5]) {
    c.drawLine(Offset(x, -7), Offset(x, -0.8), leg);
  }
  // Body: rump, the hump high over the shoulders, the neck.
  final torso =
      Path()
        ..moveTo(-19, -10)
        ..cubicTo(-21, -17, -16, -21, -8, -21)
        ..cubicTo(-2, -22, 0, -28, 6, -28)
        ..cubicTo(11, -28, 14, -24, 15, -19)
        ..lineTo(16, -11)
        ..close();
  c.drawPath(torso, paint);
  // The skirt of long hair, hanging nearly to the ground.
  final skirt = Path()..moveTo(-19, -12);
  for (var i = 0; i <= 12; i++) {
    final x = -19 + i * 35 / 12;
    skirt.lineTo(x, i.isEven ? -3.2 : -6.2);
  }
  skirt
    ..lineTo(16, -12)
    ..close();
  c.drawPath(skirt, fillPaint(hair));
  final strand =
      Paint()
        ..color = (coat == YakCoat.white
                ? const Color(0xFF9E917E)
                : const Color(0xFF4A3D35))
            .withValues(alpha: 0.5)
        ..strokeWidth = 0.6;
  for (var x = -17.0; x < 15; x += 2.6) {
    c.drawLine(Offset(x, -13), Offset(x + 0.6, -6.5), strand);
  }
  // Head and horns.
  final head =
      grazing
          ? (Path()
            ..moveTo(13, -21)
            ..cubicTo(18, -20, 22, -13, 23, -6)
            ..cubicTo(22, -3.5, 18.5, -3.5, 17.5, -6)
            ..cubicTo(16, -11, 13, -13, 12, -15)
            ..close())
          : (Path()
            ..moveTo(13, -22)
            ..cubicTo(18, -24, 23, -20, 23.5, -15)
            ..cubicTo(23.5, -12, 20, -11, 18, -12.5)
            ..cubicTo(16, -14, 13, -15, 12, -16)
            ..close());
  c.drawPath(head, paint);
  final hornColor = p.dark ? const Color(0xFF8A93AA) : const Color(0xFFEDE3CD);
  final horn =
      Paint()
        ..color = hornColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
  final hb = grazing ? const Offset(17, -17) : const Offset(18, -21.5);
  c.drawPath(
    Path()
      ..moveTo(hb.dx, hb.dy)
      ..quadraticBezierTo(hb.dx + 4, hb.dy - 1, hb.dx + 3.5, hb.dy - 5.5),
    horn,
  );
  c.drawPath(
    Path()
      ..moveTo(hb.dx - 1.5, hb.dy + 0.5)
      ..quadraticBezierTo(hb.dx - 4.5, hb.dy - 1.5, hb.dx - 2.5, hb.dy - 5.5),
    horn..color = Color.lerp(hornColor, body, 0.35)!,
  );
  // Bushy tail.
  final tail =
      Path()
        ..moveTo(-18.5, -18)
        ..quadraticBezierTo(-22.5, -14, -21.5, -7)
        ..lineTo(-23.5, -4.5)
        ..lineTo(-19.5, -5.5)
        ..quadraticBezierTo(-19.5, -12, -17, -16)
        ..close();
  c.drawPath(
    tail,
    fillPaint(
      coat == YakCoat.pied ? p.tone(const Color(0xFFF1ECE2), 0.45) : hair,
    ),
  );
  if (coat == YakCoat.pied) {
    // White blaze down the face and a white patch on the flank.
    final white = fillPaint(p.tone(const Color(0xFFF1ECE2), 0.45));
    c.save();
    c.clipPath(head);
    c.drawOval(
      grazing ? Rect.fromLTWH(18, -14, 6, 10) : Rect.fromLTWH(19, -20, 6, 8),
      white,
    );
    c.restore();
    c.save();
    c.clipPath(torso);
    c.drawPath(
      Path()
        ..moveTo(-12, -11)
        ..cubicTo(-12, -18, -5, -21, -1, -18)
        ..cubicTo(2, -15, -1, -11, -4, -11)
        ..close(),
      white,
    );
    c.restore();
  }
  // Light along the hump and back from the sun's side.
  final sunward = (p.lightFromLeft ? -1.0 : 1.0) * facing;
  c.drawPath(
    Path()
      ..moveTo(-19.5, -13)
      ..cubicTo(-21, -17.5, -16, -20.5, -8, -20.5)
      ..cubicTo(-2, -21.5, 0, -27.3, 6, -27.3)
      ..cubicTo(10.5, -27.3, 13.5, -24, 14.5, -19.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = (coat == YakCoat.white
              ? const Color(0xFFFFFFFF)
              : p.dark
              ? const Color(0xFF6D7DA6)
              : const Color(0xFF8A7563))
          .withValues(alpha: sunward < 0 ? 0.65 : 0.35),
  );
  c.restore();
}

/// A dharma wheel between two deer, the roof ornament of a monastery's
/// main hall, standing on [b].
void drawDharmaWheel(Canvas c, Offset b, double s, BiomePalette p) {
  final gold = p.tone(_gold, 0.25);
  final goldDeep = p.tone(_goldDeep, 0.3);
  final center = b.translate(0, -6.5 * s);
  c.drawRect(
    Rect.fromLTWH(b.dx - 3.5 * s, b.dy - 1.6 * s, 7 * s, 1.6 * s),
    fillPaint(goldDeep),
  );
  c.drawCircle(center, 4.8 * s, fillPaint(gold));
  c.drawCircle(center, 3.4 * s, fillPaint(goldDeep));
  final spoke =
      Paint()
        ..color = gold
        ..strokeWidth = 0.7 * s;
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    c.drawLine(
      center,
      center + Offset(math.cos(a), math.sin(a)) * 3.4 * s,
      spoke,
    );
  }
  c.drawCircle(center, 1.1 * s, fillPaint(gold));
  // The two deer, kneeling and facing the wheel.
  for (final side in [-1.0, 1.0]) {
    final o = b.translate(side * 8.5 * s, 0);
    c.drawPath(
      Path()
        ..moveTo(o.dx - side * 3.5 * s, o.dy)
        ..lineTo(o.dx + side * 3 * s, o.dy)
        ..lineTo(o.dx + side * 2.6 * s, o.dy - 3 * s)
        ..lineTo(o.dx + side * 1.4 * s, o.dy - 6.5 * s)
        ..lineTo(o.dx + side * -0.2 * s, o.dy - 6 * s)
        ..lineTo(o.dx + side * 0.2 * s, o.dy - 3.2 * s)
        ..lineTo(o.dx - side * 3.5 * s, o.dy - 2.8 * s)
        ..close(),
      fillPaint(gold),
    );
    c.drawLine(
      o.translate(side * 1 * s, -6.2 * s),
      o.translate(side * 0.2 * s, -8.6 * s),
      Paint()
        ..color = gold
        ..strokeWidth = 0.6 * s,
    );
  }
}
