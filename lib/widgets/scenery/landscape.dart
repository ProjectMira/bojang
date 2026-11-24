/// The painters behind the learning path. Each unit is one quiet scene:
/// a sky in its own light, five ranges stepping back into haze, one
/// landmark placed with intent, and an open valley floor for the trail.
///
/// All of them paint once and sit in their own RepaintBoundary, so
/// scrolling only moves cached pictures. The only painters that repaint
/// over time are [CloudPainter] (moved by a transform, not repainted) and
/// [WindFlagsPainter], which is small.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import 'biome.dart';
import 'landmarks.dart';
import 'paint_kit.dart';
import 'props.dart';
import 'ridges.dart';

/// One range in a scene. [base] and [amp] are fractions of the ridge
/// zone, measured up from the bottom of the sky.
class _Layer {
  const _Layer(
    this.base,
    this.amp, {
    this.wavelength = 160,
    this.sharp = 0.6,
    this.detail = 0.55,
    this.snow,
    this.shade = 0.5,
    this.trees = 0,
    this.haze = 0.7,
    this.lit = 0.08,
  });

  final double base;
  final double amp;
  final double wavelength;
  final double sharp;
  final double detail;
  final double? snow;
  final double shade;

  /// Conifer tip height for a forested ridge; 0 for bare.
  final double trees;

  /// How much haze sits in front of this range's foot.
  final double haze;
  final double lit;
}

// The ranges read best as a table.
// dart format off
/// The five ranges of [biome], far to near. The first two paint in the
/// sky (they move with parallax), the rest on the horizon.
List<_Layer> _layersOf(Biome biome) => switch (biome) {
  Biome.valley => const [
    _Layer(0.34, 0.58, wavelength: 260, sharp: 0.6, snow: 0.5, shade: 0.5, lit: 0.16),
    _Layer(0.22, 0.36, wavelength: 190, sharp: 0.5, snow: 0.72, shade: 0.55, lit: 0.1),
    _Layer(0.12, 0.24, wavelength: 210, sharp: 0.2, detail: 0.4, shade: 0.35),
    _Layer(0.05, 0.15, wavelength: 280, sharp: 0.08, detail: 0.3, shade: 0.25, haze: 0.45),
    _Layer(0.0, 0.10, wavelength: 300, sharp: 0, detail: 0.2, shade: 0.15, haze: 0),
  ],
  Biome.pasture => const [
    _Layer(0.36, 0.46, wavelength: 250, sharp: 0.6, snow: 0.5, shade: 0.5, lit: 0.1),
    _Layer(0.24, 0.30, wavelength: 170, sharp: 0.3, detail: 0.45, shade: 0.4),
    _Layer(0.13, 0.22, wavelength: 230, sharp: 0.1, detail: 0.35, shade: 0.3, haze: 0.55),
    _Layer(0.05, 0.16, wavelength: 300, sharp: 0.05, detail: 0.3, shade: 0.22, haze: 0.4),
    _Layer(0.0, 0.08, wavelength: 340, sharp: 0, detail: 0.2, shade: 0.12, haze: 0),
  ],
  Biome.lake => const [
    _Layer(0.44, 0.52, wavelength: 270, sharp: 0.6, snow: 0.5, shade: 0.6, lit: 0.16),
    _Layer(0.36, 0.22, wavelength: 200, sharp: 0.4, detail: 0.45, shade: 0.5, snow: 0.82),
    _Layer(0.36, 0.04, wavelength: 320, sharp: 0, detail: 0.2, shade: 0.1, haze: 0.3),
    _Layer(0.03, 0.09, wavelength: 300, sharp: 0.1, detail: 0.3, shade: 0.2, haze: 0),
    _Layer(0.0, 0.05, wavelength: 400, sharp: 0, detail: 0.2, shade: 0.1, haze: 0),
  ],
  Biome.forest => const [
    _Layer(0.42, 0.46, wavelength: 250, sharp: 0.6, snow: 0.35, shade: 0.4, haze: 0.85),
    _Layer(0.28, 0.28, wavelength: 190, sharp: 0.3, detail: 0.4, trees: 7, shade: 0.25, haze: 0.85),
    _Layer(0.16, 0.25, wavelength: 220, sharp: 0.25, detail: 0.4, trees: 10, shade: 0.25, haze: 0.8),
    _Layer(0.06, 0.20, wavelength: 260, sharp: 0.2, detail: 0.4, trees: 14, shade: 0.25, haze: 0.55),
    _Layer(0.0, 0.08, wavelength: 340, sharp: 0, detail: 0.2, shade: 0.12, haze: 0),
  ],
  Biome.monastery => const [
    _Layer(0.36, 0.56, wavelength: 260, sharp: 0.6, snow: 0.42, shade: 0.55, lit: 0.22),
    _Layer(0.22, 0.30, wavelength: 210, sharp: 0.4, detail: 0.5, shade: 0.45, lit: 0.12),
    _Layer(0.09, 0.40, wavelength: 300, sharp: 0.3, detail: 0.45, shade: 0.42, lit: 0.1, haze: 0.4),
    _Layer(0.03, 0.12, wavelength: 300, sharp: 0.08, detail: 0.3, shade: 0.25, haze: 0.3),
    _Layer(0.0, 0.07, wavelength: 360, sharp: 0, detail: 0.2, shade: 0.12, haze: 0),
  ],
  Biome.plateau => const [
    _Layer(0.20, 0.24, wavelength: 240, sharp: 0.5, snow: 0.5, shade: 0.4, haze: 0.6, lit: 0.12),
    _Layer(0.14, 0.11, wavelength: 280, sharp: 0.2, detail: 0.35, shade: 0.3, haze: 0.55),
    _Layer(0.09, 0.05, wavelength: 420, sharp: 0.05, detail: 0.25, shade: 0.2, haze: 0.45),
    _Layer(0.04, 0.04, wavelength: 460, sharp: 0, detail: 0.2, shade: 0.15, haze: 0.3),
    _Layer(0.0, 0.03, wavelength: 520, sharp: 0, detail: 0.2, shade: 0.1, haze: 0),
  ],
  Biome.pass => const [
    _Layer(0.42, 0.56, wavelength: 230, sharp: 0.7, snow: 0.3, shade: 0.55, lit: 0.12, haze: 0.6),
    _Layer(0.30, 0.46, wavelength: 200, sharp: 0.65, snow: 0.36, shade: 0.6, haze: 0.55),
    _Layer(0.14, 0.38, wavelength: 240, sharp: 0.55, snow: 0.5, shade: 0.62, haze: 0.4),
    _Layer(0.04, 0.20, wavelength: 260, sharp: 0.3, detail: 0.4, snow: 0, shade: 0.45, haze: 0.2),
    _Layer(0.0, 0.06, wavelength: 380, sharp: 0, detail: 0.2, snow: 0, shade: 0.15, haze: 0),
  ],
};
// dart format on

/// One range painted into [canvas]; returns its ridgeline.
RidgeLine _paintLayer(
  Canvas canvas,
  _Layer l,
  int index,
  BiomePalette p, {
  required double w,
  required double h,
  required double z,
  required double bottom,
  required int seed,
}) {
  final ridge = RidgeLine.generate(
    seed: seed * 53 + index * 7 + 1,
    width: w,
    wavelength: l.wavelength,
    sharpness: l.sharp,
    detail: l.detail,
    floor: 0.08,
  );
  final baseY = h - z * l.base;
  final amp = z * l.amp;
  final shape =
      l.trees > 0
          ? treelinePath(
            ridge,
            w: w,
            baseY: baseY,
            amp: amp,
            bottom: bottom,
            tip: l.trees,
            seed: seed + index,
          )
          : null;
  paintRange(
    canvas,
    ridge,
    p,
    RangeStyle(
      rock: p.ridges[index],
      snowFrom: l.snow,
      shade: l.shade,
      lit: l.lit,
      snowShadeMix: index == 0 ? 0.75 : 1,
    ),
    w: w,
    baseY: baseY,
    amp: amp,
    bottom: bottom,
    wavelength: l.wavelength,
    seed: seed * 13 + index,
    shape: shape,
  );
  if (l.haze > 0) {
    paintHaze(
      canvas,
      w,
      top: baseY - amp * 0.55,
      bottom: baseY + 2,
      floor: bottom,
      color: p.haze,
      alpha: l.haze,
    );
  }
  return ridge;
}

/// The sky in the unit's light, its sun or moon, and the two farthest
/// ranges. The part that moves with parallax.
class SkyPainter extends CustomPainter {
  const SkyPainter({
    required this.biome,
    required this.palette,
    required this.ridgeZone,
    required this.seed,
    this.overscan = 0,
    this.seam = true,
    this.mistDepth = 130,
  });

  final Biome biome;
  final BiomePalette palette;

  /// Height at the bottom of the canvas the ranges stand in.
  final double ridgeZone;
  final int seed;

  /// Extra height painted above and below, for [Parallax].
  final double overscan;

  /// Whether the top is the cloud bank the unit rises out of.
  final bool seam;

  /// Without a [seam], how far down the veil of mist reaches.
  final double mistDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    canvas.save();
    canvas.translate(0, overscan);
    final w = size.width, h = size.height - overscan * 2;
    final z = ridgeZone;
    final horizonY = h - z * 0.3;
    final skyRect = Rect.fromLTRB(0, -overscan, w, h + overscan);
    final s = p.sky;
    canvas.drawRect(
      skyRect,
      vertical(
        Rect.fromLTRB(0, 0, w, horizonY + z * 0.1),
        [s[0], s[1], s[2], s[3]],
        const [0, 0.38, 0.78, 1],
      ),
    );
    final sun = Offset(w * p.sunAt.dx, horizonY * p.sunAt.dy);
    final r = math.Random(seed);
    if (p.dark) {
      _stars(canvas, w, horizonY, r);
    }
    // The glow: wide and faint, then close and warm.
    final wide = math.max(w, h) * 0.75;
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.glow.withValues(alpha: p.dark ? 0.22 : 0.55),
            p.glow.withValues(alpha: p.dark ? 0.06 : 0.18),
            p.glow.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: sun, radius: wide)),
    );
    if (p.rays) _rays(canvas, sun, w, h);
    final disc = p.dark ? 13.0 : 17.0;
    canvas.drawCircle(
      sun,
      disc * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [p.sun.withValues(alpha: 0.65), p.sun.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: sun, radius: disc * 3.2)),
    );
    canvas.drawCircle(sun, disc, fillPaint(p.sun));
    if (p.dark) {
      // Faint seas on the moon.
      final sea = fillPaint(const Color(0xFFB9C3DC).withValues(alpha: 0.45));
      canvas.drawCircle(sun.translate(-3.5, -2.5), 3.4, sea);
      canvas.drawCircle(sun.translate(3.5, 3), 2.4, sea);
      canvas.drawCircle(sun.translate(-1, 5), 1.6, sea);
    }

    final layers = _layersOf(biome);
    final bottom = h + overscan + 2;
    for (var i = 0; i < 2; i++) {
      _paintLayer(
        canvas,
        layers[i],
        i,
        p,
        w: w,
        h: h,
        z: z,
        bottom: bottom,
        seed: seed,
      );
    }
    // The cloud this unit rises out of (it meets the bank at the foot of
    // the unit above), or a plain veil of mist that a title can sit on.
    final depth = seam ? 130.0 : mistDepth;
    final top = Rect.fromLTRB(0, -overscan, w, depth);
    final solid = seam ? overscan + 20 : (overscan + depth * 0.55);
    canvas.drawRect(
      top,
      vertical(
        top,
        [p.mist, p.mist, p.mist.withValues(alpha: 0)],
        [0, solid / (overscan + depth), 1],
      ),
    );
    if (seam) paintCloudBank(canvas, w, 14, p, seed + 3, hangDown: true);
    canvas.restore();
  }

  void _stars(Canvas canvas, double w, double horizonY, math.Random r) {
    final count = (w * horizonY / 1500).round();
    final small = <Offset>[];
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final o = Offset(
        r.nextDouble() * w,
        40 + r.nextDouble() * (horizonY * 0.9 - 40),
      );
      final fade = 1 - (o.dy / horizonY).clamp(0.0, 1.0) * 0.7;
      final size = r.nextDouble();
      if (size > 0.93) {
        canvas.drawCircle(
          o,
          5,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFDDE6FF).withValues(alpha: 0.4 * fade),
                const Color(0x00DDE6FF),
              ],
            ).createShader(Rect.fromCircle(center: o, radius: 5)),
        );
        canvas.drawCircle(
          o,
          1.3,
          fillPaint(const Color(0xFFF4F7FF).withValues(alpha: fade)),
        );
      } else {
        small.add(o);
        paint
          ..color = const Color(
            0xFFE6ECFF,
          ).withValues(alpha: (0.25 + size * 0.5) * fade)
          ..strokeWidth = 0.8 + size * 1.0;
        canvas.drawPoints(ui.PointMode.points, [o], paint);
      }
    }
  }

  void _rays(Canvas canvas, Offset sun, double w, double h) {
    final p = palette;
    final r = math.Random(seed + 77);
    final len = h * 1.1;
    final shafts = Path();
    for (var i = 0; i < 5; i++) {
      final a = math.pi * (0.12 + i * 0.11 + r.nextDouble() * 0.04);
      final spread = 0.012 + r.nextDouble() * 0.018;
      shafts
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(
          sun.dx + math.cos(a - spread) * len,
          sun.dy + math.sin(a - spread) * len,
        )
        ..lineTo(
          sun.dx + math.cos(a + spread) * len,
          sun.dy + math.sin(a + spread) * len,
        )
        ..close();
    }
    canvas.drawPath(
      shafts,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.sun.withValues(alpha: p.dark ? 0.04 : 0.13),
            p.sun.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: len)),
    );
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.biome != biome ||
      old.palette != palette ||
      old.ridgeZone != ridgeZone ||
      old.seed != seed ||
      old.overscan != overscan ||
      old.seam != seam ||
      old.mistDepth != mistDepth;
}

/// The three nearer ranges, the unit's landmark, its water, and the near
/// slope blending into the valley floor.
class HorizonPainter extends CustomPainter {
  const HorizonPainter({
    required this.biome,
    required this.palette,
    required this.ridgeZone,
    required this.seed,
    required this.trailX,
    required this.trailWidth,
    this.scale = 1,
    this.foreground = true,
  });

  final Biome biome;
  final BiomePalette palette;
  final double ridgeZone;
  final int seed;

  /// Where the trail leaves the bottom edge, and how wide it is there.
  final double trailX;
  final double trailWidth;

  /// Landmark scale (bigger on iPad).
  final double scale;

  /// Whether to stand things on the near slope (off under a header card).
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final w = size.width, h = size.height;
    final z = ridgeZone;
    final layers = _layersOf(biome);
    final bottom = h + 2;
    final ridges = <RidgeLine>[];
    for (var i = 2; i < 5; i++) {
      if (biome == Biome.lake && i == 3) _lake(canvas, w, h, z);
      if (biome == Biome.plateau && i == 3) _saltLake(canvas, w, h, z);
      final l = layers[i];
      if (i == 4) {
        _nearSlope(canvas, l, w, h, z);
      } else {
        ridges.add(
          _paintLayer(
            canvas,
            l,
            i,
            p,
            w: w,
            h: h,
            z: z,
            bottom: bottom,
            seed: seed,
          ),
        );
      }
      if (i == 2 && biome == Biome.monastery) {
        _monastery(canvas, ridges.last, layers[2], w, h, z);
      }
      if (i == 3) _landmark(canvas, ridges.last, layers[3], w, h, z);
    }
    if (foreground) _foreground(canvas, w, h, z);
    if (trailWidth > 0) _trailHead(canvas, w, h);
  }

  double _yOn(RidgeLine r, _Layer l, double x, double h, double z) =>
      r.yAt(x, h - z * l.base, z * l.amp);

  void _nearSlope(Canvas canvas, _Layer l, double w, double h, double z) {
    final p = palette;
    final ridge = RidgeLine.generate(
      seed: seed * 53 + 29,
      width: w,
      wavelength: l.wavelength,
      sharpness: 0,
      detail: l.detail,
      floor: 0.15,
    );
    final baseY = h - z * l.base;
    final amp = z * l.amp;
    final shape = ridge.path(width: w, baseY: baseY, amp: amp, bottom: h + 2);
    final rect = Rect.fromLTRB(0, baseY - amp, w, h);
    canvas.drawPath(
      shape,
      vertical(
        rect,
        [p.near, Color.lerp(p.near, p.ground, 0.5)!, p.ground],
        const [0, 0.35, 1],
      ),
    );
    if (biome == Biome.valley) _river(canvas, w, h, z);
  }

  /// The valley's river: a ribbon from the gap in the hills down to the
  /// near meadow, widening as it comes closer.
  void _river(Canvas canvas, double w, double h, double z) {
    final p = palette;
    final y0 = h - z * 0.11, y1 = h + 4;
    final x0 = w * 0.38, x1 = w * 0.02;
    Offset at(double t) {
      final y = y0 + (y1 - y0) * t;
      final x =
          x0 + (x1 - x0) * t + math.sin(t * math.pi * 1.7 + 0.3) * w * 0.13 * t;
      return Offset(x, y);
    }

    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= 24; i++) {
      final t = i / 24;
      final c = at(t);
      final half = 1.5 + 24 * math.pow(t, 1.8);
      left.add(c.translate(-half, 0));
      right.add(c.translate(half, 0));
    }
    final river = Path()..moveTo(left.first.dx, left.first.dy);
    for (final o in left) {
      river.lineTo(o.dx, o.dy);
    }
    for (final o in right.reversed) {
      river.lineTo(o.dx, o.dy);
    }
    river.close();
    final rect = Rect.fromLTRB(0, y0, w, y1);
    canvas.drawPath(
      river,
      vertical(rect, [Color.lerp(p.water, p.haze, 0.4)!, p.water, p.waterDeep]),
    );
    // The bright line of the sky in the water.
    final glint = Path()..moveTo(at(0.05).dx, at(0.05).dy);
    for (var i = 1; i <= 20; i++) {
      final c = at(0.05 + i / 20 * 0.9);
      glint.lineTo(c.dx - 2 - 4 * (i / 20), c.dy);
    }
    canvas.drawPath(
      glint,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = p.light.withValues(alpha: p.dark ? 0.25 : 0.6),
    );
  }

  /// The turquoise lake with the far range mirrored in it.
  void _lake(Canvas canvas, double w, double h, double z) {
    final p = palette;
    final top = h - z * 0.36, bottom = h - z * 0.02;
    final lake = Rect.fromLTRB(0, top, w, bottom);
    canvas.drawRect(
      lake,
      vertical(
        lake,
        [Color.lerp(p.water, p.haze, 0.45)!, p.water, p.waterDeep],
        const [0, 0.35, 1],
      ),
    );
    canvas.save();
    canvas.clipRect(lake);
    // Reflection of the far snow range, upside down and softened.
    final layers = _layersOf(biome);
    final l = layers[0];
    final ridge = RidgeLine.generate(
      seed: seed * 53 + 1,
      width: w,
      wavelength: l.wavelength,
      sharpness: l.sharp,
      detail: l.detail,
      floor: 0.08,
    );
    final amp = z * l.amp * 0.55;
    final mirror = Path()..moveTo(-ridge.margin, top);
    final offset = z * (l.base - 0.36) * 0.55;
    for (var x = -ridge.margin; x <= w + ridge.margin; x += ridge.step) {
      mirror.lineTo(x, top + offset + ridge.at(x) * amp);
    }
    mirror
      ..lineTo(w + ridge.margin, top)
      ..close();
    canvas.drawPath(
      mirror,
      fillPaint(
        Color.lerp(
          p.waterDeep,
          p.light,
          p.dark ? 0.25 : 0.5,
        )!.withValues(alpha: 0.28),
      ),
    );
    // Glints toward the sun.
    final r = math.Random(seed + 5);
    final glint =
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.3;
    final sx = w * p.sunAt.dx;
    for (var i = 0; i < w / 14; i++) {
      final y = top + 6 + r.nextDouble() * (bottom - top - 10);
      final near = (y - top) / (bottom - top);
      final x = sx + (r.nextDouble() - 0.5) * w * (0.25 + near * 0.5);
      final len = 6 + r.nextDouble() * 16 * (0.5 + near);
      glint.color = p.light.withValues(
        alpha: (p.dark ? 0.16 : 0.5) * (1 - (x - sx).abs() / w),
      );
      canvas.drawLine(Offset(x, y), Offset(x + len, y), glint);
    }
    canvas.restore();
    // The far shore line.
    canvas.drawLine(
      Offset(0, top + 0.5),
      Offset(w, top + 0.5),
      Paint()
        ..color = p.light.withValues(alpha: p.dark ? 0.15 : 0.45)
        ..strokeWidth = 1,
    );
  }

  /// A white salt lake far out on the plain.
  void _saltLake(Canvas canvas, double w, double h, double z) {
    final p = palette;
    final c = Offset(w * 0.3, h - z * 0.085);
    final rect = Rect.fromCenter(center: c, width: w * 0.62, height: z * 0.035);
    canvas.drawOval(rect, vertical(rect, [p.water, p.waterDeep]));
    canvas.drawOval(
      rect.deflate(2).translate(w * 0.04, -0.5),
      fillPaint(p.light.withValues(alpha: p.dark ? 0.15 : 0.55)),
    );
  }

  void _monastery(
    Canvas canvas,
    RidgeLine ridge,
    _Layer l,
    double w,
    double h,
    double z,
  ) {
    final x = ridge.highest(w * 0.56, w * 0.86);
    final y = _yOn(ridge, l, x, h, z);
    final s = (z / 185).clamp(0.9, 1.5) * scale;
    drawMonasteryHero(
      canvas,
      Offset(x, y + 6 * s),
      s,
      palette,
      (xx) => _yOn(ridge, l, xx, h, z),
    );
  }

  /// The unit's landmark on the third range (the one just behind the near
  /// slope).
  void _landmark(
    Canvas canvas,
    RidgeLine ridge,
    _Layer l,
    double w,
    double h,
    double z,
  ) {
    final p = palette;
    final s = (z / 210).clamp(0.85, 1.35) * scale;
    double y(double x) => _yOn(ridge, l, x, h, z) + 3 * s;
    switch (biome) {
      case Biome.valley:
        // A farmstead across the river: two whitewashed homes, lamp-lit
        // at night.
        final h1 = w * 0.22, h2 = w * 0.1;
        drawTibetanHome(
          canvas,
          Offset(h1, y(h1) + 5),
          s * 0.62,
          p,
          floors: 1,
          flip: true,
        );
        drawTibetanHome(canvas, Offset(h2, y(h2) + 6), s * 0.82, p);
        final x = w * 0.72;
        drawChortenHero(canvas, Offset(x, y(x) + 6), s * 1.05, p);
      case Biome.pasture:
        final x = w * 0.22;
        drawTentHero(canvas, Offset(x + 44 * s, y(x + 44 * s) + 3), s * 0.8, p);
        drawTentHero(canvas, Offset(x, y(x) + 7), s * 1.15, p);
      case Biome.plateau:
        // A lone nomad camp far out on the plain.
        drawTentHero(canvas, Offset(w * 0.16, h - z * 0.07), s * 0.5, p);
        for (final (fx, f) in [(0.25, -1.0), (0.29, 1.0)]) {
          drawYakHero(
            canvas,
            Offset(w * fx, h - z * 0.065),
            s * 0.4,
            p,
            facing: f,
            grazing: f < 0,
          );
        }
        for (final (fx, k, dy) in [
          (0.6, 0.85, 0.0),
          (0.665, 0.8, 3.0),
          (0.71, 0.9, 1.0),
          (0.8, 0.7, -2.0),
        ]) {
          final xx = w * fx;
          drawKiang(
            canvas,
            Offset(xx, h - z * 0.05 + dy),
            s * k,
            p,
            facing: -1,
          );
        }
      case Biome.pass:
        final x = ridge.lowest(w * 0.38, w * 0.62);
        drawLhatseHero(canvas, Offset(x, y(x) + 2), s * 0.9, p);
      case Biome.forest:
      case Biome.lake:
      case Biome.monastery:
        break;
    }
  }

  /// Things standing on the near slope, in front of everything.
  void _foreground(Canvas canvas, double w, double h, double z) {
    final p = palette;
    final s = (z / 210).clamp(0.85, 1.35) * scale;
    switch (biome) {
      case Biome.forest:
        // A farmhouse in the clearing at the edge of the trees.
        drawTibetanHome(
          canvas,
          Offset(w * 0.73, h - z * 0.015),
          s * 0.95,
          p,
          flip: true,
        );
        // A few tall firs framing the scene.
        for (final (fx, k, tone) in [
          (0.06, 1.0, 0.2),
          (0.16, 0.72, 0.7),
          (0.9, 0.92, 0.4),
        ]) {
          drawFirHero(
            canvas,
            Offset(w * fx, h - z * 0.02),
            s * k,
            p,
            seed: (fx * 100).round(),
            tone: tone,
          );
        }
      case Biome.pasture:
        // The herd grazing on the near slope: black yaks and a pied one.
        _herd(canvas, w, h, z, s, const [
          (0.64, 0.035, 0.92, -1.0, YakCoat.black, true),
          (0.74, 0.012, 0.95, 1.0, YakCoat.pied, false),
          (0.83, 0.045, 0.8, -1.0, YakCoat.black, true),
          (0.9, 0.02, 0.92, -1.0, YakCoat.black, false),
        ]);
      case Biome.pass:
        // Two pack yaks crossing the snow below the pass.
        _herd(canvas, w, h, z, s, const [
          (0.76, 0.03, 0.8, -1.0, YakCoat.black, false),
          (0.86, 0.045, 0.74, -1.0, YakCoat.pied, false),
        ]);
      case Biome.lake:
        // Mani stones on the near shore.
        drawManiPile(canvas, Offset(w * 0.12, h - z * 0.03), s * 0.9, p, 4);
        // Yaks come down to the water.
        _herd(canvas, w, h, z, s, const [
          (0.25, 0.004, 0.78, 1.0, YakCoat.black, true),
          (0.34, 0.018, 0.7, -1.0, YakCoat.pied, false),
        ]);
      default:
        break;
    }
  }

  void _herd(
    Canvas canvas,
    double w,
    double h,
    double z,
    double s,
    List<(double, double, double, double, YakCoat, bool)> yaks,
  ) {
    for (final (fx, fy, k, facing, coat, grazing) in yaks) {
      drawYakHero(
        canvas,
        Offset(w * fx, h - z * fy),
        s * k,
        palette,
        facing: facing,
        coat: coat,
        grazing: grazing,
      );
    }
  }

  void _trailHead(Canvas canvas, double w, double h) {
    final p = palette;
    final crest = h - 10;
    final tw = trailWidth;
    final path =
        Path()
          ..moveTo(trailX - tw / 2, h + 1)
          ..quadraticBezierTo(trailX - tw * 0.3, crest + 5, trailX - 2, crest)
          ..lineTo(trailX + 2, crest)
          ..quadraticBezierTo(
            trailX + tw * 0.3,
            crest + 5,
            trailX + tw / 2,
            h + 1,
          )
          ..close();
    canvas.drawPath(path, fillPaint(p.trail.withValues(alpha: 0.55)));
  }

  @override
  bool shouldRepaint(HorizonPainter old) =>
      old.biome != biome ||
      old.palette != palette ||
      old.ridgeZone != ridgeZone ||
      old.seed != seed ||
      old.trailX != trailX ||
      old.trailWidth != trailWidth ||
      old.scale != scale ||
      old.foreground != foreground;
}

/// Where prayer flags hang over a scene of [size], or none.
List<(Offset, Offset, double)> flagStringsFor(
  Biome biome,
  Size size,
  double ridgeZone,
) {
  final w = size.width, h = size.height, z = ridgeZone;
  return switch (biome) {
    // One long line across the lake shore.
    Biome.lake => [
      (Offset(w * 0.03, h - z * 0.27), Offset(w * 0.97, h - z * 0.23), 20),
    ],
    // From the chorten's knoll across to a pole.
    Biome.valley => [
      (Offset(w * 0.46, h - z * 0.16), Offset(w * 0.98, h - z * 0.22), 12),
    ],
    Biome.monastery => [
      (Offset(w * 0.02, h - z * 0.12), Offset(w * 0.34, h - z * 0.06), 10),
    ],
    _ => const [],
  };
}

/// The page under a short header: the near meadow fading into the mist,
/// with the cloud bank along it.
class MistFloorPainter extends CustomPainter {
  const MistFloorPainter({required this.palette, this.seed = 0});

  final BiomePalette palette;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      vertical(rect, [p.ground, Color.lerp(p.ground, p.mist, 0.5)!, p.mist]),
    );
    paintCloudBank(
      canvas,
      size.width,
      size.height - 18,
      p,
      seed,
      hangDown: false,
      scale: 0.8,
    );
  }

  @override
  bool shouldRepaint(MistFloorPainter old) =>
      old.palette != palette || old.seed != seed;
}

/// A few painterly clouds, tiled twice across the width so a translation
/// of up to one width loops seamlessly.
class CloudPainter extends CustomPainter {
  const CloudPainter({
    required this.palette,
    required this.seed,
    required this.top,
    required this.bottom,
  });

  final BiomePalette palette;
  final int seed;

  /// The band (fractions of the height) the clouds float in.
  final double top;
  final double bottom;

  bool get dark => palette.dark;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final w = size.width / 2;
    final r = math.Random(seed);
    final (count, minW, maxW, flat) = switch (p.biome) {
      Biome.pasture => (2, 80.0, 130.0, 0.35),
      Biome.plateau => (2, 150.0, 240.0, 0.9),
      Biome.forest => (1, 110.0, 150.0, 0.75),
      Biome.pass => (1, 70.0, 100.0, 0.55),
      _ => (2, 70.0, 120.0, 0.6),
    };
    final n = count + (w > 600 ? count : 0);
    for (var i = 0; i < n; i++) {
      final cw = minW + r.nextDouble() * (maxW - minW);
      final cx = (i + 0.2 + r.nextDouble() * 0.6) * w / n;
      final cy = size.height * (top + r.nextDouble() * (bottom - top));
      final cs = r.nextInt(9999);
      for (final dx in [0.0, w]) {
        paintCloud(
          canvas,
          Offset(cx + dx, cy),
          cw,
          p,
          cs,
          opacity: p.dark ? 0.7 : 0.92,
          flat: flat,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CloudPainter old) =>
      old.palette != palette ||
      old.seed != seed ||
      old.top != top ||
      old.bottom != bottom;
}

/// Prayer flag strings that stir in the wind. With no [wind] they hang
/// still.
class WindFlagsPainter extends CustomPainter {
  WindFlagsPainter({required this.palette, required this.strings, this.wind})
    : super(repaint: wind);

  final BiomePalette palette;

  /// Each string's two anchors and its sag.
  final List<(Offset, Offset, double)> strings;
  final Animation<double>? wind;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = wind == null ? 0.0 : wind!.value * math.pi * 2 * 24;
    final pole =
        Paint()
          ..color = palette.tone(const Color(0xFF5E4630), 0.5)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    for (final (a, b, _) in strings) {
      canvas.drawLine(a.translate(0, -4), a.translate(0, 46), pole);
      canvas.drawLine(b.translate(0, -4), b.translate(0, 46), pole);
    }
    for (final (a, b, sag) in strings) {
      drawFlagString(
        canvas,
        a,
        b,
        sag,
        palette,
        phase: phase == 0 ? 0 : phase + 0.001,
        size: 1.15,
      );
    }
  }

  @override
  bool shouldRepaint(WindFlagsPainter old) =>
      old.palette != palette ||
      old.wind != wind ||
      !listEquals(old.strings, strings);
}

/// Where the path's steps sit on the valley floor, for the ground painter.
@immutable
class TrailLayout {
  const TrailLayout({
    required this.centers,
    required this.keepClear,
    required this.walked,
    required this.trailWidth,
    required this.columnLeft,
    required this.columnRight,
    required this.swing,
    required this.propScale,
  });

  /// Centre of each step's disc.
  final List<Offset> centers;

  /// Areas props must avoid: each step with its label and Start button.
  final List<Rect> keepClear;

  /// How many steps the learner has reached (walked trail ends at the
  /// last one); 0 when the unit is still locked.
  final int walked;
  final double trailWidth;
  final double columnLeft;
  final double columnRight;
  final double swing;
  final double propScale;

  @override
  bool operator ==(Object other) =>
      other is TrailLayout &&
      listEquals(other.centers, centers) &&
      listEquals(other.keepClear, keepClear) &&
      other.walked == walked &&
      other.trailWidth == trailWidth &&
      other.columnLeft == columnLeft &&
      other.columnRight == columnRight &&
      other.swing == swing &&
      other.propScale == propScale;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(centers),
    Object.hashAll(keepClear),
    walked,
    trailWidth,
    columnLeft,
    columnRight,
    swing,
    propScale,
  );
}

/// The valley floor: gentle swells of ground with a little grain, the
/// worn trail through every step, a handful of small things beside it,
/// and the cloud bank at the bottom leading to the next unit.
class GroundPainter extends CustomPainter {
  const GroundPainter({
    required this.biome,
    required this.palette,
    required this.layout,
    required this.seed,
    required this.fade,
  });

  final Biome biome;
  final BiomePalette palette;
  final TrailLayout layout;
  final int seed;

  /// Height of the fade into mist at the bottom.
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final floorEnd = h - fade;
    canvas.drawRect(
      rect,
      vertical(
        rect,
        [p.ground, Color.lerp(p.ground, p.groundShade, 0.7)!, p.groundShade],
        [0, (floorEnd / h * 0.6).clamp(0.0, 1.0), 1],
      ),
    );
    final cx = w / 2;
    final points = [Offset(cx, -4), ...layout.centers, Offset(cx, h + 4)];
    final samples = _sampleTrail(points);
    final r = math.Random(seed);

    bool nearTrail(Offset o, double pad) {
      for (final s in samples) {
        if ((s - o).distanceSquared <
            math.pow(layout.trailWidth / 2 + pad, 2)) {
          return true;
        }
      }
      return false;
    }

    bool clear(Offset o, double pad) {
      for (final k in layout.keepClear) {
        if (k.inflate(pad).contains(o)) return false;
      }
      return !nearTrail(o, pad) && o.dy < floorEnd - 30;
    }

    _swells(canvas, w, floorEnd, r);
    _texture(canvas, w, floorEnd, (o) => !nearTrail(o, 4));
    _trail(canvas, points);
    _details(canvas, w, floorEnd, r, clear);

    // The cloud bank down to the next valley.
    final fr = Rect.fromLTRB(0, floorEnd, w, h);
    canvas.drawRect(
      fr,
      vertical(
        fr,
        [
          p.mist.withValues(alpha: 0),
          Color.lerp(p.mist, p.haze, 0.3)!.withValues(alpha: 0.7),
          p.mist,
        ],
        const [0, 0.55, 1],
      ),
    );
    paintCloudBank(canvas, w, h - 26, p, seed + 41, hangDown: false);
  }

  /// Rolling ground: each swell has a lit crest fading down its face and a
  /// shadowed dip before the next one.
  void _swells(Canvas canvas, double w, double floorEnd, math.Random r) {
    final p = palette;
    final noise = Noise1D(seed * 3 + 11);
    final gap = switch (biome) {
      Biome.plateau => 360.0,
      Biome.pass => 300.0,
      _ => 260.0,
    };
    var y = 90.0 + r.nextDouble() * 60;
    while (y < floorEnd - 40) {
      final amp = 22 + r.nextDouble() * 26;
      final phase = r.nextDouble() * 100;
      final crest = Path()..moveTo(-10, y + 200);
      final line = <Offset>[];
      for (var x = -10.0; x <= w + 10; x += 8) {
        final yy = y + noise.fbm(x / 210 + phase, octaves: 3) * amp * 2;
        line.add(Offset(x, yy));
      }
      for (final o in line) {
        crest.lineTo(o.dx, o.dy);
      }
      crest
        ..lineTo(w + 10, y + 200)
        ..close();
      // Shadow in the dip just before the crest.
      final dip = Path()..moveTo(-10, y - 90);
      for (final o in line) {
        dip.lineTo(o.dx, o.dy);
      }
      dip
        ..lineTo(w + 10, y - 90)
        ..close();
      final dipRect = Rect.fromLTRB(0, y - 90, w, y + amp);
      canvas.drawPath(
        dip,
        vertical(dipRect, [
          p.groundShade.withValues(alpha: 0),
          p.groundShade.withValues(alpha: p.dark ? 0.26 : 0.2),
        ]),
      );
      final litRect = Rect.fromLTRB(0, y - amp * 2, w, y + 150);
      canvas.drawPath(
        crest,
        vertical(
          litRect,
          [
            p.groundLight.withValues(alpha: p.dark ? 0.22 : 0.3),
            p.groundLight.withValues(alpha: 0.1),
            p.groundLight.withValues(alpha: 0),
          ],
          const [0, 0.35, 1],
        ),
      );
      y += gap * (0.8 + r.nextDouble() * 0.45);
    }
  }

  void _texture(
    Canvas canvas,
    double w,
    double floorEnd,
    bool Function(Offset) keep,
  ) {
    final p = palette;
    final area = Rect.fromLTRB(0, 0, w, floorEnd);
    final light = p.groundLight.withValues(alpha: p.dark ? 0.35 : 0.5);
    final dark = p.groundShade.withValues(alpha: p.dark ? 0.6 : 0.45);
    switch (biome) {
      case Biome.valley:
      case Biome.pasture:
      case Biome.forest:
        paintGrain(
          canvas,
          area,
          seed,
          light: light,
          dark: dark,
          density: 2.2,
          length: 4,
          spread: 0.35,
          keep: keep,
        );
      case Biome.lake:
      case Biome.monastery:
        paintGrain(
          canvas,
          area,
          seed,
          light: light,
          dark: dark,
          density: 1.8,
          length: 3.4,
          spread: 0.6,
          keep: keep,
        );
      case Biome.plateau:
        // Wind-combed: long, low strokes.
        paintGrain(
          canvas,
          area,
          seed,
          light: light,
          dark: dark,
          density: 1.4,
          length: 9,
          angle: 0,
          spread: 0.08,
          width: 1.4,
          keep: keep,
        );
      case Biome.pass:
        paintGrain(
          canvas,
          area,
          seed,
          light: p.groundLight.withValues(alpha: 0.7),
          dark: p.groundShade.withValues(alpha: 0.5),
          density: 1.2,
          length: 12,
          angle: 0.05,
          spread: 0.1,
          width: 1.6,
          keep: keep,
        );
    }
  }

  List<Offset> _sampleTrail(List<Offset> pts) {
    final out = <Offset>[];
    for (var i = 0; i < pts.length - 1; i++) {
      for (var t = 0.0; t < 1; t += 0.1) {
        out.add(_catmull(pts, i, t));
      }
    }
    return out;
  }

  static Offset _catmull(List<Offset> pts, int i, double t) {
    final p0 = pts[math.max(0, i - 1)];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[math.min(pts.length - 1, i + 2)];
    final t2 = t * t, t3 = t2 * t;
    return (p1 * 2 +
            (p2 - p0) * t +
            (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
            (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
        0.5;
  }

  Path _trailPath(List<Offset> pts, int segments) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < segments && i < pts.length - 1; i++) {
      final p0 = pts[math.max(0, i - 1)];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[math.min(pts.length - 1, i + 2)];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  /// A worn path: soft dusty edges, beaten earth, a paler line down the
  /// middle where most feet go. Unwalked, only a faint track.
  void _trail(Canvas canvas, List<Offset> pts) {
    final p = palette;
    final tw = layout.trailWidth;
    final all = _trailPath(pts, pts.length - 1);
    Paint stroke(Color c, double width) =>
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final dust = Color.lerp(p.groundShade, p.trailEdge, 0.5)!;
    canvas.drawPath(all, stroke(dust.withValues(alpha: 0.14), tw + 12));
    canvas.drawPath(all, stroke(dust.withValues(alpha: 0.22), tw + 5));
    canvas.drawPath(
      all,
      stroke(p.trail.withValues(alpha: p.dark ? 0.35 : 0.42), tw - 2),
    );
    if (layout.walked > 0) {
      final walked = _trailPath(pts, layout.walked);
      canvas.drawPath(
        walked,
        stroke(p.trailEdge.withValues(alpha: 0.3), tw + 8),
      );
      canvas.drawPath(
        walked,
        stroke(p.trailEdge.withValues(alpha: 0.55), tw + 2),
      );
      canvas.drawPath(walked, stroke(p.trail, tw - 2));
      canvas.drawPath(
        walked,
        stroke(
          Color.lerp(
            p.trail,
            p.light,
            p.dark ? 0.12 : 0.45,
          )!.withValues(alpha: 0.8),
          tw * 0.32,
        ),
      );
    }
  }

  /// A handful of small things beside the trail: never more than one in
  /// each stretch of floor, always in the margins.
  void _details(
    Canvas canvas,
    double w,
    double floorEnd,
    math.Random r,
    bool Function(Offset, double) clear,
  ) {
    final p = palette;
    final s = layout.propScale;
    final cx = w / 2;
    final margin = layout.columnLeft;
    final placed = <Offset>[];
    var side = r.nextBool() ? 1.0 : -1.0;
    final stretch = 340.0;
    var k = 0;
    for (
      var y = 120.0;
      y < floorEnd - 60;
      y += stretch * (0.85 + r.nextDouble() * 0.4)
    ) {
      for (final extra in margin > 90 ? [false, true] : [false]) {
        final sd = extra ? -side : side;
        final reach =
            extra
                ? cx - margin * (0.35 + r.nextDouble() * 0.3)
                : layout.swing + 64 * s + r.nextDouble() * 20;
        final x = (cx + sd * reach).clamp(30.0 * s, w - 30 * s);
        final o = Offset(x, y + r.nextDouble() * 60);
        if (!clear(o, 26 * s)) continue;
        if (placed.any((q) => (q - o).distance < 120 * s)) continue;
        placed.add(o);
        _detail(canvas, o, s * (extra ? 1.1 : 1), k++);
      }
      side = -side;
    }
    // Small clusters of flowers or stones near the details, never alone.
    final tuft = p.groundShade.withValues(alpha: p.dark ? 0.8 : 0.7);
    for (final o in placed) {
      for (var i = 0; i < 3; i++) {
        final q = o.translate(
          (r.nextDouble() - 0.5) * 70 * s,
          10 + r.nextDouble() * 14 * s,
        );
        if (!clear(q, 6)) continue;
        switch (biome) {
          case Biome.valley:
          case Biome.pasture:
            i == 0
                ? drawFlowers(canvas, q, 0.9 * s, p, k * 7 + i)
                : drawTuft(canvas, q, 0.9 * s, tuft);
          case Biome.forest:
            drawTuft(canvas, q, s, tuft);
          case Biome.pass:
            if (i == 0) drawRock(canvas, q, 0.5 * s, p, snowy: true);
          default:
            i == 0
                ? drawRock(canvas, q, 0.4 * s, p)
                : drawTuft(canvas, q, 0.8 * s, tuft);
        }
      }
    }
  }

  void _detail(Canvas canvas, Offset o, double s, int k) {
    final p = palette;
    switch (biome) {
      case Biome.valley:
        switch (k % 3) {
          case 0:
            for (var i = 0; i < 3; i++) {
              drawPoplar(
                canvas,
                o.translate((i - 1) * 11 * s, (i.isEven ? 0 : -3) * s),
                s * (0.9 + i * 0.08),
                p,
                hue: i / 3,
              );
            }
          case 1:
            drawManiPile(canvas, o, s * 0.85, p, k);
          default:
            drawHouse(canvas, o, s * 0.85, p, flip: k.isOdd);
        }
      case Biome.pasture:
        k.isEven
            ? drawYak(
              canvas,
              o,
              s,
              p,
              facing: k % 4 == 0 ? 1 : -1,
              white: k % 4 == 2,
            )
            : drawFlowers(canvas, o, s * 1.2, p, k);
      case Biome.lake:
        k.isEven
            ? drawManiPile(canvas, o, s * 0.85, p, k)
            : drawRock(canvas, o, s * 0.8, p);
      case Biome.forest:
        drawConifer(
          canvas,
          o.translate(-10 * s, -4 * s),
          s * 1.05,
          p,
          tone: 0.3,
        );
        drawConifer(canvas, o.translate(9 * s, 2 * s), s * 0.85, p, tone: 0.8);
      case Biome.monastery:
        k.isEven
            ? drawChorten(canvas, o, s * 0.75, p)
            : drawSangBurner(canvas, o, s * 0.9, p);
      case Biome.plateau:
        k.isEven
            ? drawKiang(canvas, o, s * 0.95, p, facing: k % 4 == 0 ? 1 : -1)
            : drawRock(canvas, o, s * 0.9, p);
      case Biome.pass:
        drawRock(canvas, o, s * 1.1, p, snowy: true);
    }
  }

  @override
  bool shouldRepaint(GroundPainter old) =>
      old.biome != biome ||
      old.palette != palette ||
      old.layout != layout ||
      old.seed != seed ||
      old.fade != fade;
}

/// A strip of lake shore to close a page: a low rise out of the mist with
/// a chorten, a mani pile, a flag pole and a grazing yak.
class ShorePainter extends CustomPainter {
  const ShorePainter({required this.palette});

  final BiomePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final w = size.width, h = size.height;
    final hill = RidgeLine.generate(
      seed: 5,
      width: w,
      wavelength: 320,
      sharpness: 0,
      detail: 0.25,
      floor: 0.35,
    );
    final base = h;
    final amp = h * 0.55;
    final shape = hill.path(width: w, baseY: base, amp: amp, bottom: h + 2);
    final rect = Rect.fromLTRB(0, h - amp, w, h);
    canvas.drawPath(
      shape,
      vertical(rect, [Color.lerp(p.ground, p.mist, 0.35)!, p.ground]),
    );
    double groundAt(double x) => hill.yAt(x, base, amp) + 10;
    final s = (h / 110).clamp(1.0, 1.6);
    drawFlagString(
      canvas,
      Offset(w * 0.18, groundAt(w * 0.18) - 58 * s),
      Offset(w * 0.46, groundAt(w * 0.46) - 30 * s),
      12,
      p,
    );
    drawChortenHero(canvas, Offset(w * 0.18, groundAt(w * 0.18)), s * 0.85, p);
    drawManiPile(canvas, Offset(w * 0.32, groundAt(w * 0.32)), s * 0.9, p, 4);
    drawDarchen(
      canvas,
      Offset(w * 0.46, groundAt(w * 0.46)),
      s * 0.9,
      p,
      color: 2,
    );
    drawYak(canvas, Offset(w * 0.68, groundAt(w * 0.68)), s, p, facing: -1);
  }

  @override
  bool shouldRepaint(ShorePainter old) => old.palette != palette;
}
