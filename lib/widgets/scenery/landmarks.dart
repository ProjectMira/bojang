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
      c.drawRect(frame, fillPaint(p.frame));
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

  // Halls down the slope on the side away from the light, smaller as they
  // go down.
  for (var i = 4; i >= 1; i--) {
    final x = b.dx + dir * i * 19 * s;
    final y = groundAt(x) + 4 * s;
    final hw = (22 - i * 1.2) * s, hh = (16 - i * 0.8) * s;
    final r = Rect.fromLTWH(x - hw / 2, y - hh, hw, hh);
    c.drawRect(r, across(r, white, whiteShade, p));
    c.drawRect(
      Rect.fromLTWH(
        r.left - 0.5 * s,
        r.top - 2.4 * s,
        r.width + 1 * s,
        2.6 * s,
      ),
      fillPaint(penbey),
    );
    windows(
      Rect.fromLTRB(
        r.left + 3 * s,
        r.top + 2 * s,
        r.right - 3 * s,
        r.bottom - 4 * s,
      ),
      2,
      2.2 * s,
    );
  }
  // The great hall's whitewashed base.
  final base = Rect.fromLTWH(b.dx - 26 * s, b.dy - 14 * s, 52 * s, 18 * s);
  c.drawRect(base, across(base, white, whiteShade, p));
  windows(
    Rect.fromLTRB(
      base.left + 4 * s,
      base.top + 2 * s,
      base.right - 4 * s,
      base.bottom - 6 * s,
    ),
    4,
    2.4 * s,
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
  for (final dx in [-11.0, 0.0, 11.0]) {
    final x = b.dx + dx * s;
    final top = hall.top - (dx == 0 ? 17 : 14) * s;
    c.drawRect(
      Rect.fromLTRB(x - 1.6 * s, top, x + 1.6 * s, hall.top - 7 * s),
      fillPaint(gold),
    );
    c.drawCircle(Offset(x, top), 1.9 * s, fillPaint(gold));
  }
  // Two victory banners on the roof corners.
  for (final x in [hall.left + 1 * s, hall.right - 1 * s]) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 1.8 * s, hall.top - 9 * s, x + 1.8 * s, hall.top),
        Radius.circular(1.6 * s),
      ),
      fillPaint(p.tone(const Color(0xFF2E2520), 0.4)),
    );
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
