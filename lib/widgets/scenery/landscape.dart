/// The painters behind the learning path: for each unit a sky with its far
/// ranges, a horizon with the biome's landmark, and the valley floor the
/// trail crosses.
///
/// All of them paint once and sit in their own RepaintBoundary, so
/// scrolling only moves cached pictures. The only painters that repaint
/// over time are [CloudPainter] (moved by a transform, not repainted) and
/// [WindFlagsPainter], which is small.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import 'biome.dart';
import 'props.dart';
import 'ridges.dart';

Paint _fill(Color c) => Paint()..color = c;

/// Sky gradient, stars or sun, and the farthest range. The part that
/// moves with parallax.
class SkyPainter extends CustomPainter {
  const SkyPainter({
    required this.biome,
    required this.palette,
    required this.ridgeZone,
    required this.seed,
    this.overscan = 0,
  });

  final Biome biome;
  final BiomePalette palette;

  /// Height at the bottom of the canvas the mountains stand in.
  final double ridgeZone;
  final int seed;

  /// Extra height painted above and below, for [Parallax].
  final double overscan;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    canvas.save();
    canvas.translate(0, overscan);
    final w = size.width, h = size.height - overscan * 2;
    final horizonY = h - ridgeZone;
    final skyRect = Rect.fromLTRB(0, -overscan, w, h + overscan);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.mist, p.mist, p.skyHigh, p.horizon, p.horizon],
          stops: [
            0,
            0.04,
            (horizonY * 0.55 / h).clamp(0.1, 0.6),
            (horizonY + ridgeZone * 0.2) / h,
            1,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    final r = math.Random(seed);
    if (p.dark) {
      final star = Paint();
      final count = (w * horizonY / 2600).round();
      for (var i = 0; i < count; i++) {
        final o = Offset(
          r.nextDouble() * w,
          24 + r.nextDouble() * (horizonY * 0.95 - 24),
        );
        star.color = const Color(
          0xFFE8EEFF,
        ).withValues(alpha: 0.35 + r.nextDouble() * 0.55);
        canvas.drawCircle(o, 0.5 + r.nextDouble() * 0.9, star);
      }
      // A crescent moon low over the ranges.
      final moon = Offset(w * 0.82, horizonY + ridgeZone * 0.02);
      canvas.drawCircle(
        moon,
        30,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFDDE6F7).withValues(alpha: 0.28),
              const Color(0x00DDE6F7),
            ],
          ).createShader(Rect.fromCircle(center: moon, radius: 30)),
      );
      canvas.saveLayer(Rect.fromCircle(center: moon, radius: 14), Paint());
      canvas.drawCircle(moon, 10, _fill(const Color(0xFFF1F4FB)));
      canvas.drawCircle(
        moon.translate(4.5, -3),
        9,
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();
    } else {
      // A pale sun sinking behind the far range.
      final sun = Offset(w * 0.84, horizonY + ridgeZone * 0.08);
      canvas.drawCircle(
        sun,
        64,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF6DA).withValues(alpha: 0.75),
              const Color(0x00FFF6DA),
            ],
          ).createShader(Rect.fromCircle(center: sun, radius: 64)),
      );
      canvas.drawCircle(sun, 17, _fill(const Color(0xFFFFF8E4)));
    }
    _farRange(canvas, w, h);
    // The cloud bank this unit came up through.
    final puff = _fill(p.mist);
    var x = -10.0;
    while (x < w + 40) {
      final rr = 16 + r.nextDouble() * 22;
      canvas.drawCircle(Offset(x, 4 + r.nextDouble() * 8), rr, puff);
      x += rr * 1.3;
    }
    canvas.restore();
  }

  void _farRange(Canvas canvas, double w, double h) {
    final p = palette;
    final z = ridgeZone;
    final (spacing, ampK, snowK, smooth, jag) = switch (biome) {
      Biome.pass => (120.0, 1.05, 0.05, false, 0.025),
      Biome.lake => (150.0, 0.85, 0.45, false, 0.02),
      Biome.plateau => (190.0, 0.5, 0.3, true, 0.0),
      Biome.forest => (110.0, 0.7, 0.85, false, 0.015),
      Biome.pasture => (140.0, 0.75, 0.6, false, 0.02),
      Biome.monastery => (130.0, 0.85, 0.5, false, 0.02),
      Biome.valley => (130.0, 0.75, 0.72, false, 0.02),
    };
    final range = MountainRange.generate(
      seed: seed * 31 + 7,
      width: w,
      spacing: spacing,
      smooth: smooth,
    );
    final baseY = h - z * 0.3;
    final amp = z * ampK;
    final bottom = h + overscan + 2;
    final shape = range.path(
      width: w,
      baseY: baseY,
      amp: amp,
      bottom: bottom,
      jag: jag,
    );
    paintSnowRange(
      canvas,
      shape,
      range,
      w: w,
      baseY: baseY,
      amp: amp,
      bottom: bottom,
      rock: p.far,
      snowLine: baseY - amp * (1 - snowK),
      palette: p,
      jag: jag,
    );
    // Haze at the foot of the range: distance.
    canvas.save();
    canvas.clipPath(shape);
    final haze = Rect.fromLTRB(0, baseY - amp * 0.45, w, bottom);
    canvas.drawRect(
      haze,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.horizon.withValues(alpha: 0),
            p.horizon.withValues(alpha: 0.75),
          ],
        ).createShader(haze),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.biome != biome ||
      old.palette != palette ||
      old.ridgeZone != ridgeZone ||
      old.seed != seed ||
      old.overscan != overscan;
}

/// Fills [shape] in [rock], snows everything above a ragged [snowLine],
/// and shades the right-hand face of each peak.
void paintSnowRange(
  Canvas canvas,
  Path shape,
  MountainRange range, {
  required double w,
  required double baseY,
  required double amp,
  required double bottom,
  required Color rock,
  required double snowLine,
  required BiomePalette palette,
  double jag = 0,
}) {
  final p = palette;
  canvas.drawPath(shape, _fill(rock));
  canvas.save();
  canvas.clipPath(shape);
  final snow = Path()..moveTo(-2, -10);
  for (var x = -2.0; x <= w + 6; x += 6) {
    final streak =
        math.sin(x * 0.11) * 5 +
        math.sin(x * 0.37 + 1) * 4 +
        (math.sin(x * 0.9) > 0.6 ? 9 : 0);
    snow.lineTo(x, snowLine + streak);
  }
  snow
    ..lineTo(w + 6, -10)
    ..close();
  canvas.drawPath(snow, _fill(p.snow));
  // Shadowed faces: from each peak down and to the right.
  final shade = _fill(p.snowShade.withValues(alpha: p.dark ? 0.55 : 0.6));
  final rockShade = _fill(
    const Color(0xFF1C2433).withValues(alpha: p.dark ? 0.25 : 0.12),
  );
  for (var i = 0; i < range.peakCount; i++) {
    final px = range.peakX(i);
    if (px < -range.peakWidth(i) || px > w + range.peakWidth(i)) continue;
    final py = range.yAt(px, baseY, amp, jag: jag);
    final pw = range.peakWidth(i);
    final face =
        Path()
          ..moveTo(px, py)
          ..lineTo(px + pw, bottom)
          ..lineTo(px + pw * 0.12, bottom)
          ..close();
    canvas.save();
    canvas.clipPath(snow);
    canvas.drawPath(face, shade);
    canvas.restore();
    canvas.drawPath(face, rockShade);
  }
  canvas.restore();
}

/// The middle range with the biome's landmark (the lake, the monastery,
/// the glacier...), then the near slope blending into the valley floor.
class HorizonPainter extends CustomPainter {
  const HorizonPainter({
    required this.biome,
    required this.palette,
    required this.ridgeZone,
    required this.seed,
    required this.trailX,
    required this.trailWidth,
  });

  final Biome biome;
  final BiomePalette palette;
  final double ridgeZone;
  final int seed;

  /// Where the trail leaves the bottom edge, and how wide it is there.
  final double trailX;
  final double trailWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final w = size.width, h = size.height;
    final z = ridgeZone;
    final midBase = h - z * 0.1;
    final midAmp = switch (biome) {
      Biome.plateau => z * 0.16,
      Biome.pass => z * 0.55,
      Biome.monastery => z * 0.5,
      Biome.forest => z * 0.48,
      _ => z * 0.36,
    };
    final mid = MountainRange.generate(
      seed: seed * 17 + 3,
      width: w,
      spacing: biome == Biome.plateau ? 220 : 160,
      smooth: biome != Biome.pass && biome != Biome.forest,
      minHeight: 0.35,
    );
    final midPath = mid.path(
      width: w,
      baseY: midBase,
      amp: midAmp,
      bottom: h + 2,
      jag: biome == Biome.pass ? 0.03 : 0,
    );
    if (biome == Biome.pass) {
      paintSnowRange(
        canvas,
        midPath,
        mid,
        w: w,
        baseY: midBase,
        amp: midAmp,
        bottom: h + 2,
        rock: p.mid,
        snowLine: midBase - midAmp * 0.55,
        palette: p,
        jag: 0.03,
      );
      _saddle(canvas, mid, w, midBase, midAmp, h);
    } else {
      canvas.drawPath(midPath, _fill(p.mid));
      canvas.save();
      canvas.clipPath(midPath);
      final band = Rect.fromLTRB(0, midBase - midAmp, w, h);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.mid, Color.lerp(p.mid, p.horizon, 0.35)!],
          ).createShader(band),
      );
      canvas.restore();
    }
    if (biome == Biome.forest) _forestCrest(canvas, mid, w, midBase, midAmp);
    if (biome == Biome.monastery) _monastery(canvas, mid, w, midBase, midAmp);

    // Water on the horizon: the lake, the valley river, the salt lake.
    final waterTop = h - z * 0.2;
    if (biome == Biome.lake || biome == Biome.plateau) {
      final water = Path()..moveTo(-2, waterTop + 6);
      for (var x = -2.0; x <= w + 8; x += 8) {
        water.lineTo(x, waterTop + math.sin(x * 0.012 + seed) * 5);
      }
      water
        ..lineTo(w + 8, h - z * 0.1)
        ..lineTo(-2, h - z * 0.1)
        ..close();
      final rect = Rect.fromLTRB(0, waterTop - 6, w, h);
      canvas.drawPath(
        water,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.waterDeep, p.water],
          ).createShader(rect),
      );
      final glint =
          Paint()
            ..color = const Color(
              0xFFFFFFFF,
            ).withValues(alpha: p.dark ? 0.18 : 0.45)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round;
      final r = math.Random(seed + 5);
      for (var i = 0; i < w / 40; i++) {
        final x = r.nextDouble() * w;
        final y = waterTop + 6 + r.nextDouble() * (z * 0.12);
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 8 + r.nextDouble() * 18, y),
          glint,
        );
      }
    }

    // The near slope: rolling, fading into the valley floor colour.
    final near = MountainRange.generate(
      seed: seed * 7 + 1,
      width: w,
      spacing: 200,
      smooth: true,
      minHeight: 0.3,
    );
    final nearBase = h;
    final nearAmp = z * (biome == Biome.plateau ? 0.08 : 0.15);
    final nearPath = near.path(
      width: w,
      baseY: nearBase,
      amp: nearAmp,
      bottom: h + 2,
    );
    final nr = Rect.fromLTRB(0, nearBase - nearAmp, w, h);
    canvas.drawPath(
      nearPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.near, p.ground],
        ).createShader(nr),
    );
    if (biome == Biome.valley) _river(canvas, w, h, nearAmp);

    if (trailWidth <= 0) return;
    // The trail climbing over the near slope, narrowing with distance.
    final crest = math.min(h - 6, near.yAt(trailX + 6, nearBase, nearAmp) + 3);
    final trail =
        Path()
          ..moveTo(trailX - trailWidth / 2, h + 1)
          ..quadraticBezierTo(
            trailX - trailWidth * 0.3,
            crest + (h - crest) * 0.4,
            trailX + 4,
            crest,
          )
          ..lineTo(trailX + 8, crest)
          ..quadraticBezierTo(
            trailX + trailWidth * 0.3,
            crest + (h - crest) * 0.4,
            trailX + trailWidth / 2,
            h + 1,
          )
          ..close();
    canvas.drawPath(trail, _fill(p.trail.withValues(alpha: 0.9)));
  }

  void _river(Canvas canvas, double w, double h, double nearAmp) {
    final p = palette;
    final y = h - nearAmp * 0.4;
    final river = Path()..moveTo(-4, y + 4);
    for (var x = -4.0; x <= w + 8; x += 8) {
      river.lineTo(x, y + math.sin(x * 0.02 + seed) * 4);
    }
    for (var x = w + 8; x >= -4; x -= 8) {
      river.lineTo(x, y + 6 + math.sin(x * 0.02 + seed) * 4);
    }
    river.close();
    canvas.drawPath(river, _fill(p.water));
  }

  void _saddle(
    Canvas canvas,
    MountainRange mid,
    double w,
    double base,
    double amp,
    double h,
  ) {
    final p = palette;
    // The lowest saddle near the middle is the pass.
    var bestX = w * 0.5, bestY = -1.0;
    for (var x = w * 0.3; x <= w * 0.75; x += 6) {
      final y = mid.yAt(x, base, amp, jag: 0.03);
      if (y > bestY) {
        bestY = y;
        bestX = x;
      }
    }
    // The la itself: a cairn with prayer flags on the saddle.
    drawLhatse(canvas, Offset(bestX, bestY + 3), 0.6, p);
  }

  void _forestCrest(
    Canvas canvas,
    MountainRange mid,
    double w,
    double base,
    double amp,
  ) {
    final p = palette;
    final r = math.Random(seed + 11);
    final dark = _fill(
      Color.lerp(p.mid, const Color(0xFF0E2219), p.dark ? 0.3 : 0.25)!,
    );
    for (var x = -4.0; x < w + 8; x += 5 + r.nextDouble() * 5) {
      final y = mid.yAt(x, base, amp) + 2;
      final th = 8 + r.nextDouble() * 9;
      canvas.drawPath(
        Path()
          ..moveTo(x - th * 0.28, y)
          ..lineTo(x, y - th)
          ..lineTo(x + th * 0.28, y)
          ..close(),
        dark,
      );
    }
  }

  /// A monastery on the highest ridge to the right: whitewashed halls
  /// stepping up the slope to a red temple with a gold roof.
  void _monastery(
    Canvas canvas,
    MountainRange mid,
    double w,
    double base,
    double amp,
  ) {
    final p = palette;
    var bestX = w * 0.75, bestY = double.infinity;
    for (var x = w * 0.58; x <= w * 0.9; x += 4) {
      final y = mid.yAt(x, base, amp);
      if (y < bestY) {
        bestY = y;
        bestX = x;
      }
    }
    final s = (amp / 70).clamp(0.8, 1.5);
    final white = _fill(p.wall);
    final frame = _fill(p.frame);
    final window = _fill(p.window);
    // Halls down the left slope.
    for (var i = 3; i >= 1; i--) {
      final x = bestX - i * 16 * s;
      final y = mid.yAt(x, base, amp) + 3 * s;
      final r = Rect.fromLTWH(x - 9 * s, y - 13 * s, 18 * s, 14 * s);
      canvas.drawRect(r, white);
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top - 2 * s, r.width, 2.2 * s),
        _fill(p.tone(const Color(0xFF6E2A20), 0.5)),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: r.center.translate(0, -1 * s),
          width: 3.4 * s,
          height: 3.6 * s,
        ),
        frame,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: r.center.translate(0, -1 * s),
          width: 2 * s,
          height: 2.2 * s,
        ),
        window,
      );
    }
    // The red temple.
    final base0 = bestY + 6 * s;
    final hall = Rect.fromLTWH(bestX - 15 * s, base0 - 26 * s, 30 * s, 26 * s);
    canvas.drawRect(
      Rect.fromLTWH(
        hall.left - 6 * s,
        base0 - 10 * s,
        hall.width + 12 * s,
        10 * s,
      ),
      white,
    );
    canvas.drawRect(hall, _fill(p.tone(const Color(0xFF9B2F22), 0.5)));
    canvas.drawRect(
      Rect.fromLTWH(hall.left, hall.top, hall.width, 4 * s),
      _fill(p.tone(const Color(0xFF5A1E16), 0.5)),
    );
    for (var i = 0; i < 3; i++) {
      final c = Offset(hall.left + 6 * s + i * 9 * s, hall.top + 13 * s);
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 4.2 * s, height: 6 * s),
        frame,
      );
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 2.4 * s, height: 4 * s),
        window,
      );
    }
    final gold = _fill(p.tone(const Color(0xFFE5A928), 0.3));
    canvas.drawPath(
      Path()
        ..moveTo(hall.left + 4 * s, hall.top)
        ..lineTo(hall.left + 8 * s, hall.top - 7 * s)
        ..lineTo(hall.right - 8 * s, hall.top - 7 * s)
        ..lineTo(hall.right - 4 * s, hall.top)
        ..close(),
      gold,
    );
    for (final dx in [-9.0, 9.0]) {
      final x = bestX + dx * s;
      canvas.drawRect(
        Rect.fromLTWH(x - 1.4 * s, hall.top - 13 * s, 2.8 * s, 6 * s),
        gold,
      );
    }
    canvas.drawCircle(Offset(bestX, hall.top - 9 * s), 2.2 * s, gold);
  }

  @override
  bool shouldRepaint(HorizonPainter old) =>
      old.biome != biome ||
      old.palette != palette ||
      old.ridgeZone != ridgeZone ||
      old.seed != seed ||
      old.trailX != trailX ||
      old.trailWidth != trailWidth;
}

/// The meadow at the foot of a scene fading into the page's mist, with
/// the cloud bank along it.
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
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.ground, p.mist],
        ).createShader(rect),
    );
    final r = math.Random(seed);
    final puff = _fill(p.mist);
    var x = -10.0;
    while (x < size.width + 40) {
      final rr = 14 + r.nextDouble() * 20;
      canvas.drawCircle(
        Offset(x, size.height - 4 - r.nextDouble() * 8),
        rr,
        puff,
      );
      x += rr * 1.3;
    }
  }

  @override
  bool shouldRepaint(MistFloorPainter old) =>
      old.palette != palette || old.seed != seed;
}

/// A few clouds, tiled twice across the width so a translation of up to
/// one width loops seamlessly.
class CloudPainter extends CustomPainter {
  const CloudPainter({
    required this.dark,
    required this.seed,
    required this.top,
    required this.bottom,
  });

  final bool dark;
  final int seed;

  /// The band (fractions of the height) the clouds float in.
  final double top;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 2;
    final r = math.Random(seed);
    final paint = _fill(
      dark
          ? const Color(0xFF2B3A5C).withValues(alpha: 0.55)
          : const Color(0xFFFFFFFF).withValues(alpha: 0.85),
    );
    final count = 2 + (w / 260).floor();
    for (var i = 0; i < count; i++) {
      final cx = (i + r.nextDouble() * 0.8) * w / count;
      final cy = size.height * (top + r.nextDouble() * (bottom - top));
      final cw = 50 + r.nextDouble() * 60;
      for (final dx in [0.0, w]) {
        final cloud = Path();
        final base = Offset(cx + dx, cy);
        for (var k = 0; k < 4; k++) {
          final rr = cw * (0.18 + 0.1 * math.sin(k * 1.7 + i));
          cloud.addOval(
            Rect.fromCircle(
              center: base.translate(
                -cw / 2 + k * cw / 3.2,
                -rr * 0.4 - (k == 1 || k == 2 ? rr * 0.35 : 0),
              ),
              radius: rr,
            ),
          );
        }
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(base.dx - cw, base.dy - cw, base.dx + cw, base.dy),
        );
        canvas.drawPath(cloud, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(CloudPainter old) =>
      old.dark != dark ||
      old.seed != seed ||
      old.top != top ||
      old.bottom != bottom;
}

/// Prayer flag strings on the near slope that stir in the wind. With no
/// [wind] they hang still.
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
    for (final (a, b, sag) in strings) {
      drawFlagString(
        canvas,
        a,
        b,
        sag,
        palette,
        phase: phase == 0 ? 0 : phase + 0.001,
        size: 1.1,
      );
    }
    // The poles.
    final pole =
        Paint()
          ..color = palette.tone(const Color(0xFF6B5136), 0.5)
          ..strokeWidth = 1.8;
    for (final (a, b, _) in strings) {
      canvas.drawLine(a, a.translate(0, 34), pole);
      canvas.drawLine(b, b.translate(0, 34), pole);
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
    walked,
    trailWidth,
    columnLeft,
    columnRight,
    swing,
    propScale,
  );
}

/// The valley floor: ground texture, the trail through every step, props
/// beside it, and the cloud bank at the bottom leading to the next unit.
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
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.ground, Color.lerp(p.ground, p.groundShade, 0.6)!],
        ).createShader(rect),
    );
    final cx = w / 2;
    final points = [Offset(cx, -4), ...layout.centers, Offset(cx, h + 4)];
    final samples = _sampleTrail(points);
    final r = math.Random(seed);

    final taken = <Rect>[];
    bool clear(Offset o, double pad) {
      for (final k in taken) {
        if (k.inflate(pad).contains(o)) return false;
      }
      for (final k in layout.keepClear) {
        if (k.inflate(pad).contains(o)) return false;
      }
      for (final s in samples) {
        if ((s - o).distanceSquared < math.pow(layout.trailWidth / 2 + pad, 2))
          return false;
      }
      return o.dy < h - fade * 0.7;
    }

    _texture(canvas, size, r, clear, taken);
    _trail(canvas, points);

    // Landmarks beside each step, on the side the trail is not.
    final props = <(Offset, int, double)>[];
    final s = layout.propScale;
    final primaryCount = _primary.length;
    for (var i = 0; i < layout.centers.length; i++) {
      final c = layout.centers[i];
      final dx = c.dx - cx;
      final sides = dx.abs() < layout.swing * 0.3 ? [-1.0, 1.0] : [-dx.sign];
      for (final side in sides) {
        final x = (cx + side * (layout.swing + 60 * s)).clamp(
          34.0 * s,
          w - 34 * s,
        );
        final o = Offset(x, c.dy + 26 * s);
        if (!clear(o, 18 * s)) continue;
        props.add((o, (i + seed + (side > 0 ? 1 : 0)) % primaryCount, s));
      }
    }
    // Wide screens: more of the valley beyond the column.
    final margin = layout.columnLeft;
    if (margin > 70) {
      for (var y = 70.0; y < h - fade; y += 130 + r.nextDouble() * 70) {
        for (final left in [true, false]) {
          final x =
              left
                  ? 30 + r.nextDouble() * (margin - 60)
                  : w - 30 - r.nextDouble() * (margin - 60);
          final o = Offset(x, y);
          if (!clear(o, 10) ||
              props.any((pr) => (pr.$1 - o).distance < 80 * s)) {
            continue;
          }
          props.add((
            Offset(x, y),
            r.nextInt(primaryCount),
            s * (0.9 + r.nextDouble() * 0.35),
          ));
        }
      }
    }
    // Small details: tufts, flowers, stones.
    final details = <Offset>[];
    final n = (w * h / (biome == Biome.forest ? 3000 : 5200)).round();
    for (var i = 0; i < n; i++) {
      final o = Offset(r.nextDouble() * w, 10 + r.nextDouble() * (h - fade));
      if (!clear(o, 8)) continue;
      if (props.any((pr) => (pr.$1 - o).distance < 46 * s)) continue;
      details.add(o);
    }
    details.sort((a, b) => a.dy.compareTo(b.dy));
    for (final o in details) {
      _detail(canvas, o, r);
    }
    props.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (final (o, kind, sc) in props) {
      _primary[kind](canvas, o, sc, kind + o.dx.round());
    }

    // The cloud bank down to the next valley.
    final fr = Rect.fromLTRB(0, h - fade, w, h);
    canvas.drawRect(
      fr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.mist.withValues(alpha: 0),
            p.mist.withValues(alpha: 0.85),
            p.mist,
          ],
          stops: const [0, 0.65, 1],
        ).createShader(fr),
    );
    final puff = _fill(p.mist);
    var x = -10.0;
    while (x < w + 40) {
      final rr = 18 + r.nextDouble() * 26;
      canvas.drawCircle(Offset(x, h - 8 - r.nextDouble() * 10), rr, puff);
      x += rr * 1.25;
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
    // Unwalked: a faint track. Walked: beaten earth with a worn centre.
    canvas.drawPath(all, stroke(p.trailEdge.withValues(alpha: 0.55), tw + 5));
    canvas.drawPath(all, stroke(p.trail.withValues(alpha: 0.6), tw));
    if (layout.walked > 0) {
      final walked = _trailPath(pts, layout.walked);
      canvas.drawPath(walked, stroke(p.trailEdge, tw + 5));
      canvas.drawPath(walked, stroke(p.trail, tw));
      canvas.drawPath(
        walked,
        stroke(
          Color.lerp(p.trail, const Color(0xFFFFFFFF), p.dark ? 0.12 : 0.45)!,
          tw * 0.28,
        ),
      );
    }
  }

  void _texture(
    Canvas canvas,
    Size size,
    math.Random r,
    bool Function(Offset, double) clear,
    List<Rect> taken,
  ) {
    final p = palette;
    final w = size.width, h = size.height;
    switch (biome) {
      case Biome.valley:
        for (var i = 0; i < w * h / 9000; i++) {
          final c = Offset(
            r.nextDouble() * w,
            20 + r.nextDouble() * (h - fade - 20),
          );
          final fw = 54 + r.nextDouble() * 70, fh = 16 + r.nextDouble() * 12;
          final rect = Rect.fromCenter(center: c, width: fw, height: fh);
          if (![
            rect.center,
            rect.topLeft,
            rect.topRight,
            rect.bottomLeft,
            rect.bottomRight,
          ].every((o) => clear(o, 6)))
            continue;
          drawField(canvas, rect, p, ripe: r.nextBool());
        }
      case Biome.pasture:
      case Biome.monastery:
        final band = _fill(p.groundShade.withValues(alpha: 0.35));
        for (var y = 80.0; y < h - fade; y += 150 + r.nextDouble() * 80) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(r.nextDouble() * w, y),
              width: w * 0.9,
              height: 46,
            ),
            band,
          );
        }
      case Biome.lake:
        for (var i = 0; i < layout.centers.length; i++) {
          final c = layout.centers[i];
          if (c.dx - w / 2 < layout.swing * 0.5) continue;
          final pond = Offset(
            math.max(40, c.dx - layout.swing * 2.6),
            c.dy + 10,
          );
          if (!clear(pond.translate(50, 0), 0) || !clear(pond, 0)) continue;
          canvas.drawOval(
            Rect.fromCenter(center: pond, width: 120, height: 46),
            _fill(p.water),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: pond.translate(4, 4),
              width: 80,
              height: 22,
            ),
            _fill(p.waterDeep.withValues(alpha: 0.5)),
          );
          taken.add(Rect.fromCenter(center: pond, width: 130, height: 60));
          break;
        }
      case Biome.forest:
        final shade = _fill(p.groundShade.withValues(alpha: 0.5));
        for (var i = 0; i < w * h / 16000; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(r.nextDouble() * w, r.nextDouble() * (h - fade)),
              width: 90,
              height: 30,
            ),
            shade,
          );
        }
      case Biome.plateau:
        final pan = _fill(
          p.tone(const Color(0xFFEDE9DD), 0.6).withValues(alpha: 0.7),
        );
        for (var i = 0; i < w * h / 30000; i++) {
          final c = Offset(
            r.nextDouble() * w,
            40 + r.nextDouble() * (h - fade - 40),
          );
          if (!clear(c, 40)) continue;
          canvas.drawOval(
            Rect.fromCenter(center: c, width: 100, height: 26),
            pan,
          );
        }
      case Biome.pass:
        final drift = _fill(p.snow.withValues(alpha: 0.75));
        final scree = _fill(
          p.tone(const Color(0xFF9AA4B1), 0.6).withValues(alpha: 0.28),
        );
        for (var i = 0; i < w * h / 12000; i++) {
          final c = Offset(r.nextDouble() * w, r.nextDouble() * (h - fade));
          canvas.drawOval(
            Rect.fromCenter(
              center: c,
              width: 70 + r.nextDouble() * 60,
              height: 18,
            ),
            i.isEven ? drift : scree,
          );
        }
    }
  }

  void _detail(Canvas canvas, Offset o, math.Random r) {
    final p = palette;
    final tuft = p.tone(
      Color.lerp(p.groundShade, const Color(0xFF2E4A22), 0.3)!,
      0.0,
    );
    final roll = r.nextDouble();
    switch (biome) {
      case Biome.pasture:
        roll < 0.45
            ? drawFlowers(canvas, o, 1, p, r.nextInt(999))
            : drawTuft(canvas, o, 1, tuft);
      case Biome.valley:
        roll < 0.25
            ? drawFlowers(canvas, o, 0.9, p, r.nextInt(999))
            : drawTuft(canvas, o, 1, tuft);
      case Biome.forest:
        roll < 0.6
            ? drawConifer(
              canvas,
              o,
              0.5 + r.nextDouble() * 0.4,
              p,
              tone: r.nextDouble(),
            )
            : drawTuft(canvas, o, 1, tuft);
      case Biome.pass:
        roll < 0.5
            ? drawRock(canvas, o, 0.6, p, snowy: true)
            : drawTuft(canvas, o, 0.8, p.groundShade);
      case Biome.plateau:
      case Biome.lake:
      case Biome.monastery:
        roll < 0.2
            ? drawRock(canvas, o, 0.45, p)
            : drawTuft(canvas, o, 0.9, tuft);
    }
  }

  List<void Function(Canvas, Offset, double, int)> get _primary {
    final p = palette;
    return switch (biome) {
      Biome.valley => [
        (c, o, s, k) => drawHouse(c, o, s, p, flip: k.isOdd),
        (c, o, s, k) => drawChorten(c, o, s, p),
        (c, o, s, k) {
          drawHouse(c, o.translate(-16 * s, -8 * s), s * 0.85, p);
          drawHouse(c, o.translate(18 * s, 2 * s), s, p, flip: true);
        },
        (c, o, s, k) {
          for (var i = 0; i < 3; i++) {
            drawPoplar(
              c,
              o.translate((i - 1) * 12 * s, (i.isEven ? 0 : -4) * s),
              s * (0.9 + i * 0.08),
              p,
              hue: i / 3,
            );
          }
        },
      ],
      Biome.pasture => [
        (c, o, s, k) => drawTent(c, o, s, p),
        (c, o, s, k) {
          drawYak(c, o.translate(-18 * s, -6 * s), s * 0.9, p, facing: 1);
          drawYak(
            c,
            o.translate(14 * s, 2 * s),
            s,
            p,
            facing: -1,
            white: k.isEven,
          );
        },
        (c, o, s, k) {
          drawTent(c, o.translate(-8 * s, 0), s * 0.9, p);
          drawYak(c, o.translate(30 * s, 8 * s), s * 0.8, p, facing: -1);
        },
        (c, o, s, k) => drawYak(c, o, s, p, facing: k.isEven ? 1 : -1),
      ],
      Biome.lake => [
        (c, o, s, k) => drawManiPile(c, o, s, p, k),
        (c, o, s, k) => drawDarchen(c, o, s, p, color: k),
        (c, o, s, k) {
          drawManiPile(c, o.translate(-10 * s, 0), s * 0.9, p, k);
          drawDarchen(c, o.translate(18 * s, 2 * s), s * 0.9, p, color: k + 2);
        },
        (c, o, s, k) => drawLhatse(c, o, s * 0.8, p),
      ],
      Biome.forest => [
        (c, o, s, k) {
          drawConifer(c, o.translate(-14 * s, -6 * s), s * 1.1, p);
          drawConifer(c, o.translate(10 * s, 0), s * 1.3, p, tone: 0.5);
          drawConifer(c, o.translate(26 * s, 6 * s), s * 0.9, p, tone: 1);
        },
        (c, o, s, k) => drawTimberHouse(c, o, s, p),
        (c, o, s, k) {
          drawConifer(c, o.translate(-12 * s, -4 * s), s * 1.2, p, tone: 0.3);
          drawRhododendron(c, o.translate(12 * s, 4 * s), s, p, k);
        },
        (c, o, s, k) => drawRhododendron(c, o, s * 1.1, p, k),
      ],
      Biome.monastery => [
        (c, o, s, k) {
          for (var i = -1; i <= 1; i++) {
            drawChorten(c, o.translate(i * 20 * s, 0), s * 0.6, p);
          }
        },
        (c, o, s, k) => drawSangBurner(c, o, s, p),
        (c, o, s, k) => drawChorten(c, o, s, p),
        (c, o, s, k) => drawHouse(c, o, s * 0.85, p, flip: k.isOdd),
      ],
      Biome.plateau => [
        (c, o, s, k) {
          drawKiang(c, o.translate(-14 * s, -4 * s), s, p, facing: 1);
          drawKiang(c, o.translate(14 * s, 3 * s), s * 0.95, p, facing: 1);
        },
        (c, o, s, k) => drawTent(c, o, s * 0.9, p),
        (c, o, s, k) => drawKiang(c, o, s, p, facing: k.isEven ? 1 : -1),
        (c, o, s, k) {
          drawRock(c, o.translate(-10 * s, 0), s, p);
          drawRock(c, o.translate(10 * s, 3 * s), s * 0.7, p);
        },
      ],
      Biome.pass => [
        (c, o, s, k) => drawLhatse(c, o, s, p),
        (c, o, s, k) {
          drawRock(c, o.translate(-12 * s, 0), s * 1.2, p, snowy: true);
          drawRock(c, o.translate(12 * s, 4 * s), s * 0.8, p, snowy: true);
        },
        (c, o, s, k) {
          drawYak(c, o.translate(-16 * s, -4 * s), s * 0.9, p, facing: -1);
          drawYak(c, o.translate(16 * s, 2 * s), s * 0.9, p, facing: -1);
        },
        (c, o, s, k) => drawRock(c, o, s * 1.3, p, snowy: true),
      ],
    };
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
/// a chorten, mani stones, a flag pole and a grazing yak.
class ShorePainter extends CustomPainter {
  const ShorePainter({required this.palette});

  final BiomePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final p = palette;
    final w = size.width, h = size.height;
    final hill = MountainRange.generate(
      seed: 5,
      width: w,
      spacing: 260,
      smooth: true,
      minHeight: 0.5,
    );
    final base = h;
    final amp = h * 0.55;
    final shape = hill.path(width: w, baseY: base, amp: amp, bottom: h + 2);
    final rect = Rect.fromLTRB(0, h - amp, w, h);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(p.ground, p.mist, 0.35)!, p.ground],
        ).createShader(rect),
    );
    double groundAt(double x) => hill.yAt(x, base, amp) + 10;
    final s = (h / 110).clamp(1.0, 1.6);
    drawFlagString(
      canvas,
      Offset(w * 0.18, groundAt(w * 0.18) - 54 * s),
      Offset(w * 0.46, groundAt(w * 0.46) - 30 * s),
      12,
      p,
    );
    drawChorten(canvas, Offset(w * 0.18, groundAt(w * 0.18)), s, p);
    drawManiPile(canvas, Offset(w * 0.32, groundAt(w * 0.32)), s * 0.9, p, 4);
    drawDarchen(
      canvas,
      Offset(w * 0.46, groundAt(w * 0.46)),
      s * 0.9,
      p,
      color: 2,
    );
    drawYak(canvas, Offset(w * 0.66, groundAt(w * 0.66)), s, p, facing: -1);
    drawManiPile(canvas, Offset(w * 0.86, groundAt(w * 0.86)), s * 0.7, p, 9);
  }

  @override
  bool shouldRepaint(ShorePainter old) => old.palette != palette;
}
