/// The small things that make a landscape Tibetan, drawn in code: houses,
/// chortens, yak-hair tents, yaks, mani stones, cairns, conifers, kiang.
///
/// Every prop is drawn from its base: [b] is the bottom centre where it
/// meets the ground, [s] scales it (1 is about 44 px tall).
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'biome.dart';

/// The five flag colours in their traditional order: blue, white, red,
/// green, yellow.
const List<Color> kLungtaColors = [
  Color(0xFF2174C8),
  Color(0xFFF7F7F2),
  Color(0xFFD23C31),
  Color(0xFF1F844F),
  Color(0xFFF2B807),
];

const Color _maroon = Color(0xFF7A2E22);
const Color _gold = Color(0xFFE0A526);
const Color _yak = Color(0xFF2B2420);

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w) =>
    Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

void contactShadow(Canvas c, Offset b, double w, BiomePalette p) {
  c.drawOval(
    Rect.fromCenter(center: b.translate(0, 1), width: w, height: w * 0.18),
    _fill(
      (p.dark ? const Color(0xFF000000) : const Color(0xFF3A3020)).withValues(
        alpha: p.dark ? 0.35 : 0.16,
      ),
    ),
  );
}

/// A whitewashed house: tapering walls, a dark parapet, black trapezoid
/// window frames (lamp-lit at night) and a prayer flag on the roof corner.
void drawHouse(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  bool flip = false,
}) {
  final w = 52 * s, h = 30 * s;
  contactShadow(c, b, w * 1.2, p);
  final wall =
      Path()
        ..moveTo(b.dx - w / 2, b.dy)
        ..lineTo(b.dx + w / 2, b.dy)
        ..lineTo(b.dx + w / 2 - 3 * s, b.dy - h)
        ..lineTo(b.dx - w / 2 + 3 * s, b.dy - h)
        ..close();
  c.drawPath(wall, _fill(p.wall));
  // The shaded side wall.
  c.drawPath(
    Path()
      ..moveTo(b.dx + w * 0.18, b.dy)
      ..lineTo(b.dx + w / 2, b.dy)
      ..lineTo(b.dx + w / 2 - 3 * s, b.dy - h)
      ..lineTo(b.dx + w * 0.18 - 1.5 * s, b.dy - h)
      ..close(),
    _fill(const Color(0xFF2A3040).withValues(alpha: p.dark ? 0.25 : 0.10)),
  );
  // Parapet.
  c.drawRect(
    Rect.fromLTRB(
      b.dx - w / 2 + 2 * s,
      b.dy - h - 4 * s,
      b.dx + w / 2 - 2 * s,
      b.dy - h + 1 * s,
    ),
    _fill(p.tone(_maroon, 0.5)),
  );
  // Windows: black frames wider at the bottom, a red lintel strip on top.
  void window(double cx, double top, double ww, double wh) {
    final frame =
        Path()
          ..moveTo(cx - ww / 2 - 2.2 * s, top + wh)
          ..lineTo(cx + ww / 2 + 2.2 * s, top + wh)
          ..lineTo(cx + ww / 2 + 0.8 * s, top)
          ..lineTo(cx - ww / 2 - 0.8 * s, top)
          ..close();
    c.drawPath(frame, _fill(p.frame));
    c.drawRect(
      Rect.fromLTWH(
        cx - ww / 2 + 0.6 * s,
        top + 1.2 * s,
        ww - 1.2 * s,
        wh - 2.4 * s,
      ),
      _fill(p.window),
    );
    c.drawRect(
      Rect.fromLTWH(cx - ww / 2 - 1 * s, top - 2 * s, ww + 2 * s, 1.6 * s),
      _fill(p.tone(const Color(0xFFC0392B), 0.45)),
    );
  }

  final dir = flip ? -1.0 : 1.0;
  window(b.dx - dir * w * 0.25, b.dy - h + 8 * s, 6 * s, 7 * s);
  window(b.dx + dir * w * 0.02, b.dy - h + 8 * s, 6 * s, 7 * s);
  // Door.
  final dx = b.dx + dir * w * 0.3;
  c.drawRect(
    Rect.fromLTWH(dx - 4.5 * s, b.dy - 12 * s, 9 * s, 12 * s),
    _fill(p.frame),
  );
  c.drawRect(
    Rect.fromLTWH(dx - 3 * s, b.dy - 10.5 * s, 6 * s, 10.5 * s),
    _fill(p.tone(const Color(0xFF8C3B2A), 0.5)),
  );
  // Roof flag.
  final px = b.dx - dir * (w / 2 - 5 * s);
  final top = b.dy - h - 18 * s;
  c.drawLine(
    Offset(px, b.dy - h - 4 * s),
    Offset(px, top),
    _stroke(p.frame, 1.2 * s),
  );
  for (var i = 0; i < 3; i++) {
    c.drawRect(
      Rect.fromLTWH(
        px + (flip ? -7 * s : 0.6 * s),
        top + i * 3 * s,
        6.4 * s,
        3 * s,
      ),
      _fill(p.tone(kLungtaColors[(i * 2) % 5], 0.35)),
    );
  }
}

/// A chorten: stepped white base, the dome, a gold spire of rings, and the
/// sun and moon on top.
void drawChorten(Canvas c, Offset b, double s, BiomePalette p) {
  contactShadow(c, b, 44 * s, p);
  final white = p.wall;
  final shade = const Color(0xFF2A3040).withValues(alpha: p.dark ? 0.28 : 0.12);
  var y = b.dy;
  for (final (w, h) in [(40.0, 6.0), (32.0, 5.0), (26.0, 5.0)]) {
    final r = Rect.fromLTWH(b.dx - w * s / 2, y - h * s, w * s, h * s);
    c.drawRect(r, _fill(white));
    c.drawRect(
      Rect.fromLTRB(b.dx + w * s * 0.2, r.top, r.right, r.bottom),
      _fill(shade),
    );
    y -= h * s;
  }
  // Dome (bumpa): wider at the shoulder.
  final dome =
      Path()
        ..moveTo(b.dx - 10 * s, y)
        ..cubicTo(
          b.dx - 13 * s,
          y - 8 * s,
          b.dx - 11 * s,
          y - 15 * s,
          b.dx - 7 * s,
          y - 15 * s,
        )
        ..lineTo(b.dx + 7 * s, y - 15 * s)
        ..cubicTo(
          b.dx + 11 * s,
          y - 15 * s,
          b.dx + 13 * s,
          y - 8 * s,
          b.dx + 10 * s,
          y,
        )
        ..close();
  c.drawPath(dome, _fill(white));
  c.drawPath(
    Path()
      ..moveTo(b.dx + 3 * s, y)
      ..lineTo(b.dx + 10 * s, y)
      ..cubicTo(
        b.dx + 13 * s,
        y - 8 * s,
        b.dx + 11 * s,
        y - 15 * s,
        b.dx + 7 * s,
        y - 15 * s,
      )
      ..lineTo(b.dx + 3 * s, y - 15 * s)
      ..close(),
    _fill(shade),
  );
  y -= 15 * s;
  c.drawRect(
    Rect.fromLTWH(b.dx - 5 * s, y - 4 * s, 10 * s, 4 * s),
    _fill(white),
  );
  y -= 4 * s;
  final gold = p.tone(_gold, 0.35);
  final spire =
      Path()
        ..moveTo(b.dx - 3.5 * s, y)
        ..lineTo(b.dx + 3.5 * s, y)
        ..lineTo(b.dx + 1.2 * s, y - 14 * s)
        ..lineTo(b.dx - 1.2 * s, y - 14 * s)
        ..close();
  c.drawPath(spire, _fill(gold));
  for (var i = 1; i < 5; i++) {
    final yy = y - i * 2.8 * s;
    c.drawLine(
      Offset(b.dx - 3.2 * s + i * 0.5 * s, yy),
      Offset(b.dx + 3.2 * s - i * 0.5 * s, yy),
      _stroke(p.tone(const Color(0xFFA9741A), 0.4), 0.7 * s),
    );
  }
  y -= 14 * s;
  c.drawCircle(Offset(b.dx, y - 2.2 * s), 1.6 * s, _fill(gold));
  c.drawArc(
    Rect.fromCircle(center: Offset(b.dx, y - 0.2 * s), radius: 2.6 * s),
    math.pi * 0.1,
    math.pi * 0.8,
    false,
    _stroke(gold, 1.1 * s),
  );
}

/// A poplar: tall narrow crown, trunk.
void drawPoplar(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  double hue = 0,
}) {
  final green = p.tone(
    Color.lerp(const Color(0xFF6F9A45), const Color(0xFF9DAF4A), hue)!,
  );
  final dark = p.tone(const Color(0xFF4F7A33));
  c.drawLine(
    b,
    b.translate(0, -12 * s),
    _stroke(p.tone(const Color(0xFF6B5136)), 2 * s),
  );
  final crown = Rect.fromCenter(
    center: b.translate(0, -30 * s),
    width: 13 * s,
    height: 40 * s,
  );
  c.drawOval(crown, _fill(green));
  c.save();
  c.clipRect(
    Rect.fromLTRB(crown.center.dx, crown.top, crown.right, crown.bottom),
  );
  c.drawOval(crown, _fill(dark.withValues(alpha: 0.55)));
  c.restore();
}

/// A black yak-hair tent (ba): low and wide with a peaked ridge, guy ropes
/// to the pegs and smoke from the roof slit.
void drawTent(Canvas c, Offset b, double s, BiomePalette p) {
  final w = 54 * s, h = 22 * s;
  contactShadow(c, b, w * 1.3, p);
  final rope = _stroke(p.tone(const Color(0xFF5A4A3C), 0.5), 0.8 * s);
  for (final side in [-1.0, 1.0]) {
    c.drawLine(
      Offset(b.dx + side * w * 0.3, b.dy - h * 0.95),
      Offset(b.dx + side * w * 0.85, b.dy),
      rope,
    );
    c.drawLine(
      Offset(b.dx + side * w * 0.45, b.dy - h * 0.7),
      Offset(b.dx + side * w * 0.95, b.dy - 1),
      rope,
    );
  }
  final tent =
      Path()
        ..moveTo(b.dx - w / 2, b.dy)
        ..lineTo(b.dx - w * 0.38, b.dy - h * 0.8)
        ..lineTo(b.dx - w * 0.08, b.dy - h)
        ..lineTo(b.dx, b.dy - h * 1.12)
        ..lineTo(b.dx + w * 0.08, b.dy - h)
        ..lineTo(b.dx + w * 0.38, b.dy - h * 0.8)
        ..lineTo(b.dx + w / 2, b.dy)
        ..close();
  c.drawPath(tent, _fill(p.dark ? const Color(0xFF15120F) : _yak));
  // Woven strips.
  for (var i = -2; i <= 2; i++) {
    c.drawLine(
      Offset(b.dx + i * w * 0.15, b.dy - h * 0.95 + (i.abs()) * 1.5 * s),
      Offset(b.dx + i * w * 0.19, b.dy),
      _stroke(const Color(0xFF4A3F37).withValues(alpha: 0.7), 0.7 * s),
    );
  }
  // Doorway: warm at night.
  final door =
      Path()
        ..moveTo(b.dx - 5 * s, b.dy)
        ..lineTo(b.dx, b.dy - 11 * s)
        ..lineTo(b.dx + 5 * s, b.dy)
        ..close();
  c.drawPath(
    door,
    _fill(p.dark ? const Color(0xFFF3B44C) : const Color(0xFF8A6A4A)),
  );
  // Smoke.
  final smoke = _stroke(
    (p.dark ? const Color(0xFF8D9AB3) : const Color(0xFFFFFFFF)).withValues(
      alpha: 0.7,
    ),
    2.2 * s,
  );
  final top = b.translate(0, -h * 1.15);
  c.drawPath(
    Path()
      ..moveTo(top.dx, top.dy)
      ..cubicTo(
        top.dx - 5 * s,
        top.dy - 6 * s,
        top.dx + 6 * s,
        top.dy - 11 * s,
        top.dx + 1 * s,
        top.dy - 18 * s,
      ),
    smoke,
  );
}

/// A yak: shaggy skirt, hump, pale curved horns. [facing] is 1 (right) or
/// -1 (left).
void drawYak(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  double facing = 1,
  bool white = false,
}) {
  contactShadow(c, b, 34 * s, p);
  c.save();
  c.translate(b.dx, b.dy);
  c.scale(facing * s, s);
  final body =
      p.dark
          ? const Color(0xFF14110E)
          : (white ? const Color(0xFFEDE6DA) : _yak);
  final paint = _fill(body);
  final legs = _stroke(body, 3.2);
  for (final x in [-10.0, -6.0, 6.0, 10.0]) {
    c.drawLine(Offset(x, -8), Offset(x, -0.5), legs);
  }
  final torso =
      Path()
        ..moveTo(-15, -10)
        ..cubicTo(-16, -17, -10, -21, -2, -20)
        ..cubicTo(4, -24, 10, -22, 13, -17)
        ..lineTo(15, -10)
        // Shaggy skirt.
        ..lineTo(13, -6)
        ..lineTo(11, -9)
        ..lineTo(9, -5)
        ..lineTo(6, -8.5)
        ..lineTo(3, -5)
        ..lineTo(0, -8.5)
        ..lineTo(-3, -5)
        ..lineTo(-6, -8.5)
        ..lineTo(-9, -5)
        ..lineTo(-12, -8.5)
        ..lineTo(-15, -6)
        ..close();
  c.drawPath(torso, paint);
  // Light along the hump and back, from the sun's side.
  final sunward = (p.lightFromLeft ? -1.0 : 1.0) * facing;
  c.drawPath(
    Path()
      ..moveTo(-14.5, -12)
      ..cubicTo(-15.5, -17, -10, -20.5, -2, -19.6)
      ..cubicTo(4, -23.4, 9.5, -21.6, 12.5, -17),
    _stroke(
      (white
              ? const Color(0xFFFFFFFF)
              : p.dark
              ? const Color(0xFF6D7DA6)
              : const Color(0xFF7A6656))
          .withValues(alpha: sunward < 0 ? 0.55 : 0.35),
      1.3,
    ),
  );
  // Head, low and forward.
  c.drawPath(
    Path()
      ..moveTo(12, -18)
      ..cubicTo(17, -19, 21, -15, 20, -11)
      ..cubicTo(19, -8, 15, -9, 13, -11)
      ..close(),
    paint,
  );
  final horn = _stroke(
    p.dark ? const Color(0xFF7D8699) : const Color(0xFFE9DFC9),
    1.6,
  );
  c.drawPath(
    Path()
      ..moveTo(16, -17)
      ..quadraticBezierTo(15, -22, 19, -23),
    horn,
  );
  // Tail.
  c.drawLine(
    const Offset(-15, -16),
    const Offset(-18, -10),
    _stroke(body, 1.6),
  );
  c.restore();
}

/// A kiang, the wild ass of the Changtang: chestnut back, white belly and
/// legs, a dark stripe down the back.
void drawKiang(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  double facing = 1,
}) {
  contactShadow(c, b, 30 * s, p);
  c.save();
  c.translate(b.dx, b.dy);
  c.scale(facing * s, s);
  final coat = p.tone(const Color(0xFFA8683A), 0.55);
  final belly = p.tone(const Color(0xFFF3EDE2), 0.5);
  final legs = _stroke(belly, 2.2);
  for (final x in [-9.0, -6.0, 7.0, 10.0]) {
    c.drawLine(Offset(x, -10), Offset(x, -0.5), legs);
  }
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -19, 25, 10),
      const Radius.circular(5),
    ),
    _fill(belly),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -19, 25, 6),
      const Radius.circular(4),
    ),
    _fill(coat),
  );
  // Neck and head.
  c.drawPath(
    Path()
      ..moveTo(9, -18)
      ..lineTo(14, -27)
      ..lineTo(19, -25)
      ..lineTo(20, -21)
      ..lineTo(16, -21)
      ..lineTo(13, -14)
      ..close(),
    _fill(coat),
  );
  c.drawLine(const Offset(15, -27), const Offset(15, -31), _stroke(coat, 1.6));
  c.drawLine(
    const Offset(-11, -18),
    const Offset(12, -19),
    _stroke(p.tone(const Color(0xFF4A2E1C), 0.5), 1.1),
  );
  c.drawLine(
    const Offset(-12, -17),
    const Offset(-15, -10),
    _stroke(coat, 1.3),
  );
  c.restore();
}

/// Wildflowers: a few stems of blue poppy, yellow and white.
void drawFlowers(Canvas c, Offset b, double s, BiomePalette p, int seed) {
  final r = math.Random(seed);
  const colors = [
    Color(0xFF6E9FE0),
    Color(0xFFF2C94C),
    Color(0xFFFFFFFF),
    Color(0xFFE76F6F),
  ];
  for (var i = 0; i < 6; i++) {
    final o = b.translate(
      (r.nextDouble() - 0.5) * 22 * s,
      -r.nextDouble() * 6 * s,
    );
    c.drawLine(
      o,
      o.translate(0, -4 * s),
      _stroke(p.tone(const Color(0xFF4E7B3A)), 0.8 * s),
    );
    c.drawCircle(
      o.translate(0, -4.5 * s),
      1.7 * s,
      _fill(p.tone(colors[r.nextInt(colors.length)], 0.45)),
    );
  }
}

/// Grass tufts.
void drawTuft(Canvas c, Offset b, double s, Color color) {
  final paint = _stroke(color, 1.2 * s);
  for (final a in [-0.5, -0.15, 0.2, 0.5]) {
    c.drawLine(
      b,
      b.translate(math.sin(a) * 7 * s, -math.cos(a) * 7 * s),
      paint,
    );
  }
}

/// A heap of mani stones, some painted, some with carved lines.
void drawManiPile(Canvas c, Offset b, double s, BiomePalette p, int seed) {
  final r = math.Random(seed);
  contactShadow(c, b, 40 * s, p);
  final stones = [
    for (var row = 0; row < 3; row++)
      for (var i = 0; i < 4 - row; i++)
        (
          Offset(
            b.dx + (i - (3 - row) / 2) * 9 * s + (r.nextDouble() - 0.5) * 2 * s,
            b.dy - 3.5 * s - row * 6 * s,
          ),
          r.nextInt(7),
        ),
  ];
  const painted = [
    Color(0xFF2174C8),
    Color(0xFFD23C31),
    Color(0xFFF2B807),
    Color(0xFF1F844F),
  ];
  for (final (o, k) in stones) {
    final rect = Rect.fromCenter(center: o, width: 10 * s, height: 7 * s);
    final color = k < 4 ? painted[k] : const Color(0xFFA7A49C);
    c.drawOval(rect, _fill(p.tone(color, 0.5)));
    c.drawLine(
      rect.center.translate(-2.5 * s, 0),
      rect.center.translate(2.5 * s, 0),
      _stroke(
        p.tone(const Color(0xFFFFFFFF), 0.4).withValues(alpha: 0.85),
        0.8 * s,
      ),
    );
  }
}

/// A string of prayer flags hanging between [a] and [b], sagging by [sag].
/// [phase] moves them in the wind; 0 holds them still.
void drawFlagString(
  Canvas c,
  Offset a,
  Offset b,
  double sag,
  BiomePalette p, {
  double phase = 0,
  double size = 1,
}) {
  final line = _stroke(
    p.dark ? const Color(0xFF59647A) : const Color(0xFF6B5E4E),
    0.8,
  );
  Offset at(double t) {
    final x = a.dx + (b.dx - a.dx) * t;
    final y = a.dy + (b.dy - a.dy) * t + sag * 4 * t * (1 - t);
    return Offset(x, y);
  }

  final path = Path()..moveTo(a.dx, a.dy);
  for (var t = 0.05; t <= 1.0001; t += 0.05) {
    final o = at(t);
    path.lineTo(o.dx, o.dy);
  }
  c.drawPath(path, line);
  final n = math.max(4, ((b - a).distance / (9 * size)).floor());
  for (var i = 1; i < n; i++) {
    final t = i / n;
    final o = at(t);
    final sway = phase == 0 ? 0.0 : math.sin(phase + i * 0.8) * 1.8 * size;
    final w = 6.0 * size, h = 7.5 * size;
    final flag =
        Path()
          ..moveTo(o.dx - w / 2, o.dy)
          ..lineTo(o.dx + w / 2, o.dy)
          ..lineTo(o.dx + w / 2 + sway, o.dy + h)
          ..lineTo(o.dx - w / 2 + sway * 0.6, o.dy + h * 0.96)
          ..close();
    c.drawPath(flag, _fill(p.tone(kLungtaColors[i % 5], 0.42)));
  }
}

/// A lhatse: a cairn of stones on a pass, bristling with sticks, with flag
/// strings fanning down to the ground on both sides.
void drawLhatse(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  double phase = 0,
}) {
  final top = b.translate(0, -30 * s);
  drawFlagString(
    c,
    top.translate(0, 2 * s),
    b.translate(-46 * s, 2 * s),
    6 * s,
    p,
    phase: phase,
    size: s * 0.9,
  );
  drawFlagString(
    c,
    top.translate(0, 2 * s),
    b.translate(48 * s, 4 * s),
    7 * s,
    p,
    phase: phase + 1,
    size: s * 0.9,
  );
  contactShadow(c, b, 36 * s, p);
  final cairn =
      Path()
        ..moveTo(b.dx - 16 * s, b.dy)
        ..quadraticBezierTo(
          b.dx - 12 * s,
          b.dy - 18 * s,
          b.dx - 3 * s,
          b.dy - 24 * s,
        )
        ..lineTo(b.dx + 3 * s, b.dy - 24 * s)
        ..quadraticBezierTo(b.dx + 13 * s, b.dy - 18 * s, b.dx + 16 * s, b.dy)
        ..close();
  c.drawPath(cairn, _fill(p.tone(const Color(0xFF8E8A82), 0.55)));
  final r = math.Random(7);
  for (var i = 0; i < 9; i++) {
    final o = b.translate(
      (r.nextDouble() - 0.5) * 22 * s,
      -(2 + r.nextDouble() * 18) * s,
    );
    c.drawOval(
      Rect.fromCenter(center: o, width: 6 * s, height: 4 * s),
      _fill(
        p.tone(
          i.isEven ? const Color(0xFFB3AEA4) : const Color(0xFF6F6B64),
          0.55,
        ),
      ),
    );
  }
  final stick = _stroke(p.tone(const Color(0xFF6B5136), 0.5), 1.1 * s);
  for (final a in [-0.35, -0.1, 0.15, 0.4]) {
    c.drawLine(
      top.translate(0, 8 * s),
      top.translate(math.sin(a) * 12 * s, -math.cos(a) * 8 * s),
      stick,
    );
  }
  // A white khata tied round it.
  c.drawLine(
    b.translate(-9 * s, -14 * s),
    b.translate(9 * s, -16 * s),
    _stroke(p.tone(const Color(0xFFFFFFFF), 0.35), 2 * s),
  );
}

/// A tall darchen pole with its long vertical flag.
void drawDarchen(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  double phase = 0,
  int color = 0,
}) {
  final top = b.translate(0, -58 * s);
  c.drawLine(b, top, _stroke(p.tone(const Color(0xFF6B5136), 0.5), 1.6 * s));
  final sway = phase == 0 ? 0.0 : math.sin(phase) * 2 * s;
  final flag =
      Path()
        ..moveTo(top.dx + 1, top.dy + 3 * s)
        ..lineTo(top.dx + 9 * s + sway, top.dy + 4 * s)
        ..lineTo(top.dx + 9 * s + sway * 1.4, top.dy + 40 * s)
        ..lineTo(top.dx + 1, top.dy + 38 * s)
        ..close();
  c.drawPath(flag, _fill(p.tone(kLungtaColors[color % 5], 0.42)));
  c.drawCircle(top, 2 * s, _fill(p.tone(_gold, 0.4)));
}

/// A conifer of the Kham forests: stacked tiers, lit on the left.
void drawConifer(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  double tone = 0,
}) {
  final dark = p.tone(
    Color.lerp(const Color(0xFF244A36), const Color(0xFF2F5A3C), tone)!,
    0.6,
  );
  final light = p.tone(
    Color.lerp(const Color(0xFF3E6E4C), const Color(0xFF4F8255), tone)!,
    0.6,
  );
  c.drawLine(
    b,
    b.translate(0, -8 * s),
    _stroke(p.tone(const Color(0xFF5A4030)), 2.4 * s),
  );
  for (var i = 0; i < 4; i++) {
    final base = b.dy - 6 * s - i * 9 * s;
    final w = (22 - i * 4.5) * s;
    final tier =
        Path()
          ..moveTo(b.dx - w / 2, base)
          ..lineTo(b.dx, base - 15 * s)
          ..lineTo(b.dx + w / 2, base)
          ..close();
    c.drawPath(tier, _fill(dark));
    c.drawPath(
      Path()
        ..moveTo(b.dx - w / 2, base)
        ..lineTo(b.dx, base - 15 * s)
        ..lineTo(b.dx - w * 0.05, base)
        ..close(),
      _fill(light),
    );
  }
}

/// A Kham house: stone lower floor, timber upper floor with carved windows.
void drawTimberHouse(Canvas c, Offset b, double s, BiomePalette p) {
  final w = 46 * s;
  contactShadow(c, b, w * 1.2, p);
  c.drawRect(
    Rect.fromLTWH(b.dx - w / 2, b.dy - 16 * s, w, 16 * s),
    _fill(p.wall),
  );
  c.drawRect(
    Rect.fromLTWH(b.dx - w / 2 - 2 * s, b.dy - 30 * s, w + 4 * s, 14 * s),
    _fill(p.tone(const Color(0xFF8A5A36), 0.55)),
  );
  for (var i = 0; i < 6; i++) {
    final x = b.dx - w / 2 + i * w / 5;
    c.drawLine(
      Offset(x, b.dy - 30 * s),
      Offset(x, b.dy - 16 * s),
      _stroke(p.tone(const Color(0xFF5E3B22), 0.55), 0.7 * s),
    );
  }
  for (final x in [-0.25, 0.25]) {
    c.drawRect(
      Rect.fromCenter(
        center: Offset(b.dx + x * w, b.dy - 23 * s),
        width: 8 * s,
        height: 7 * s,
      ),
      _fill(p.frame),
    );
    c.drawRect(
      Rect.fromCenter(
        center: Offset(b.dx + x * w, b.dy - 23 * s),
        width: 5.5 * s,
        height: 4.5 * s,
      ),
      _fill(p.window),
    );
  }
  c.drawRect(
    Rect.fromLTWH(b.dx - w / 2 - 4 * s, b.dy - 33 * s, w + 8 * s, 3.5 * s),
    _fill(p.tone(const Color(0xFF4A3426), 0.55)),
  );
  c.drawRect(
    Rect.fromLTWH(b.dx - 4 * s, b.dy - 11 * s, 8 * s, 11 * s),
    _fill(p.frame),
  );
}

/// A rhododendron bush in flower.
void drawRhododendron(Canvas c, Offset b, double s, BiomePalette p, int seed) {
  final r = math.Random(seed);
  c.drawOval(
    Rect.fromCenter(
      center: b.translate(0, -8 * s),
      width: 28 * s,
      height: 17 * s,
    ),
    _fill(p.tone(const Color(0xFF2F5B3F), 0.6)),
  );
  for (var i = 0; i < 7; i++) {
    c.drawCircle(
      b.translate(
        (r.nextDouble() - 0.5) * 22 * s,
        -(4 + r.nextDouble() * 10) * s,
      ),
      2.2 * s,
      _fill(
        p.tone(
          i.isEven ? const Color(0xFFE0566B) : const Color(0xFFF08AA0),
          0.5,
        ),
      ),
    );
  }
}

/// A sang burner: a small whitewashed oven with juniper smoke rising.
void drawSangBurner(Canvas c, Offset b, double s, BiomePalette p) {
  contactShadow(c, b, 22 * s, p);
  final oven =
      Path()
        ..moveTo(b.dx - 9 * s, b.dy)
        ..lineTo(b.dx + 9 * s, b.dy)
        ..lineTo(b.dx + 6 * s, b.dy - 16 * s)
        ..quadraticBezierTo(b.dx, b.dy - 22 * s, b.dx - 6 * s, b.dy - 16 * s)
        ..close();
  c.drawPath(oven, _fill(p.wall));
  c.drawRect(
    Rect.fromLTWH(b.dx - 3 * s, b.dy - 9 * s, 6 * s, 5 * s),
    _fill(p.frame),
  );
  final smoke = _stroke(
    (p.dark ? const Color(0xFF8D9AB3) : const Color(0xFFFFFFFF)).withValues(
      alpha: 0.75,
    ),
    3.2 * s,
  );
  final t = b.translate(0, -21 * s);
  c.drawPath(
    Path()
      ..moveTo(t.dx, t.dy)
      ..cubicTo(
        t.dx - 8 * s,
        t.dy - 8 * s,
        t.dx + 9 * s,
        t.dy - 15 * s,
        t.dx + 2 * s,
        t.dy - 26 * s,
      )
      ..cubicTo(
        t.dx - 4 * s,
        t.dy - 32 * s,
        t.dx + 5 * s,
        t.dy - 36 * s,
        t.dx + 8 * s,
        t.dy - 40 * s,
      ),
    smoke,
  );
}

/// A boulder.
void drawRock(
  Canvas c,
  Offset b,
  double s,
  BiomePalette p, {
  bool snowy = false,
}) {
  final rock =
      Path()
        ..moveTo(b.dx - 12 * s, b.dy)
        ..lineTo(b.dx - 9 * s, b.dy - 8 * s)
        ..lineTo(b.dx - 2 * s, b.dy - 12 * s)
        ..lineTo(b.dx + 7 * s, b.dy - 9 * s)
        ..lineTo(b.dx + 12 * s, b.dy)
        ..close();
  c.drawPath(rock, _fill(p.tone(const Color(0xFF8C8F96), 0.55)));
  c.drawPath(
    Path()
      ..moveTo(b.dx - 2 * s, b.dy - 12 * s)
      ..lineTo(b.dx + 7 * s, b.dy - 9 * s)
      ..lineTo(b.dx + 12 * s, b.dy)
      ..lineTo(b.dx + 1 * s, b.dy)
      ..close(),
    _fill(p.tone(const Color(0xFF6A6D74), 0.6)),
  );
  if (snowy) {
    c.drawPath(
      Path()
        ..moveTo(b.dx - 9 * s, b.dy - 8 * s)
        ..lineTo(b.dx - 2 * s, b.dy - 12 * s)
        ..lineTo(b.dx + 7 * s, b.dy - 9 * s)
        ..lineTo(b.dx + 2 * s, b.dy - 8 * s)
        ..lineTo(b.dx - 4 * s, b.dy - 9.5 * s)
        ..close(),
      _fill(p.snow),
    );
  }
}

/// A barley field seen from the path: a rounded strip with furrows.
void drawField(Canvas c, Rect r, BiomePalette p, {required bool ripe}) {
  final color = p.tone(
    ripe ? const Color(0xFFE2C35E) : const Color(0xFFB9C964),
    0.62,
  );
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.35));
  c.drawRRect(rr, _fill(color));
  c.save();
  c.clipRRect(rr);
  final furrow = _stroke(
    p.tone(ripe ? const Color(0xFFC9A646) : const Color(0xFF9CAE4E), 0.66),
    1.1,
  );
  for (var y = r.top + 4; y < r.bottom; y += 5) {
    c.drawLine(Offset(r.left, y), Offset(r.right, y - r.height * 0.1), furrow);
  }
  c.restore();
}
