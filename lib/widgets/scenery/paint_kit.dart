/// Shared brushes for the scenery: ranges lit from one side with snow and
/// shadow faces, haze between them, painterly clouds, grain.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'biome.dart';
import 'ridges.dart';

Paint fillPaint(Color c) => Paint()..color = c;

/// A vertical gradient over [rect]; with no [stops], evenly spaced.
Paint vertical(Rect rect, List<Color> colors, [List<double>? stops]) =>
    Paint()
      ..shader = Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        colors,
        stops ??
            (colors.length > 2
                ? [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)]
                : null),
      );

/// The air between two ranges: clear at [top], [color] at [alpha] by
/// [bottom], and solid below it down to [floor].
void paintHaze(
  Canvas canvas,
  double w, {
  required double top,
  required double bottom,
  required double floor,
  required Color color,
  double alpha = 0.85,
}) {
  if (bottom <= top) return;
  // One rect, one gradient: no seam where the fade meets the solid part.
  final end = math.max(floor, bottom + 1);
  final band = Rect.fromLTRB(-4, top, w + 4, end);
  final k = (bottom - top) / (end - top);
  canvas.drawRect(
    band,
    vertical(
      band,
      [
        color.withValues(alpha: 0),
        color.withValues(alpha: alpha * 0.55),
        color.withValues(alpha: alpha),
        color.withValues(alpha: alpha),
      ],
      [0, k * 0.6, k, 1],
    ),
  );
}

/// How one range is painted.
class RangeStyle {
  const RangeStyle({
    required this.rock,
    this.snowFrom,
    this.shade = 0.5,
    this.snowShadeMix = 1,
    this.lit = 0.1,
  });

  /// The range's own colour (already pushed back by distance).
  final Color rock;

  /// Snow covers the range above this fraction of its height; null for
  /// none.
  final double? snowFrom;

  /// How dark the faces turned from the light are (0..1).
  final double shade;

  /// How much the snow in shadow takes the shade colour.
  final double snowShadeMix;

  /// How much the lit faces take the light colour.
  final double lit;
}

/// Paints [ridge] as a range standing on [baseY]: the lit faces, the
/// shadow faces turned from the sun (each peak's spine wanders down to
/// the foot), and snow above a line that follows the ridges and runs down
/// the gullies.
Path paintRange(
  Canvas canvas,
  RidgeLine ridge,
  BiomePalette p,
  RangeStyle style, {
  required double w,
  required double baseY,
  required double amp,
  required double bottom,
  required double wavelength,
  required int seed,
  Path? shape,
}) {
  final silhouette =
      shape ?? ridge.path(width: w, baseY: baseY, amp: amp, bottom: bottom);
  final top = baseY - amp;
  final rect = Rect.fromLTRB(0, top, w, bottom);
  final litRock = Color.lerp(style.rock, p.light, style.lit)!;
  canvas.drawPath(
    silhouette,
    vertical(
      rect,
      [litRock, style.rock, Color.lerp(style.rock, p.haze, 0.35)!],
      const [0, 0.55, 1],
    ),
  );

  // Shadow faces: from each peak, a spine down to the foot; the side away
  // from the sun, between the spine and the next saddle, is in shadow.
  final dir = p.lightFromLeft ? 1.0 : -1.0;
  final noise = Noise1D(seed + 91);
  final faces = Path();
  for (final px in ridge.peaks(w, gap: wavelength * 0.45, minHeight: 0.18)) {
    final py = ridge.yAt(px, baseY, amp);
    final xv = ridge.lowest(px + dir * 3, px + dir * wavelength * 0.9);
    final reach = (xv - px).abs();
    if (reach < 6) continue;
    final face = Path()..moveTo(px, py);
    // The arête runs down and out from the summit like the silhouette
    // itself, so each face is a wedge, not a column.
    const steps = 14;
    final footX = px + dir * reach * 0.72;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final y = py + (baseY - py) * t;
      final drift = reach * 0.72 * math.pow(t, 0.85);
      final wobble = noise.fbm(px * 0.05 + t * 3.1, octaves: 3) * 6 * t;
      face.lineTo(px + dir * (drift + wobble), y);
    }
    // Below the foot the face keeps slanting out, never straight down.
    face.lineTo(footX + dir * (bottom - baseY) * 0.6, bottom);
    for (var x = xv; dir > 0 ? x > px : x < px; x -= dir * ridge.step) {
      face.lineTo(x, ridge.yAt(x, baseY, amp));
    }
    face.close();
    faces.addPath(face, Offset.zero);
    // A gully on the lit face, slanting down from the ridge, for form.
    final gx = px - dir * reach * 0.5;
    final gy = ridge.yAt(gx, baseY, amp);
    if (gy < baseY - amp * 0.3) {
      final g = Path()..moveTo(gx, gy);
      final len = (baseY - gy) * 0.6;
      for (var i = 1; i <= 8; i++) {
        final t = i / 8;
        g.lineTo(
          gx + dir * reach * 0.3 * t + noise.at(gx + t * 5) * 3,
          gy + len * t,
        );
      }
      for (var i = 8; i >= 0; i--) {
        final t = i / 8;
        g.lineTo(gx + dir * (reach * 0.3 * t + 1 + 5 * t), gy + len * t - 1);
      }
      g.close();
      faces.addPath(g, Offset.zero);
    }
  }

  canvas.save();
  canvas.clipPath(silhouette);
  final shadeRock = Color.lerp(style.rock, p.rockShade, style.shade)!;
  canvas.drawPath(
    faces,
    vertical(rect, [shadeRock, Color.lerp(shadeRock, p.haze, 0.3)!]),
  );

  final snowFrom = style.snowFrom;
  if (snowFrom != null) {
    final level = baseY - amp * snowFrom;
    final snow =
        Path()..moveTo(-ridge.margin, ridge.yAt(-ridge.margin, baseY, amp));
    for (var x = -ridge.margin; x <= w + ridge.margin; x += ridge.step) {
      snow.lineTo(x, ridge.yAt(x, baseY, amp));
    }
    for (var x = w + ridge.margin; x >= -ridge.margin; x -= ridge.step) {
      final ry = ridge.yAt(x, baseY, amp);
      // The snow line rises and falls with the ridge above it and runs
      // down the gullies in fingers.
      final height = ridge.at(x);
      final follow = (height - snowFrom) * amp * 0.45;
      final finger = math.max(0.0, noise.fbm(x * 0.035 + 7, octaves: 3));
      final gully = finger * finger * amp * 0.9;
      final wave = noise.fbm(x * 0.012, octaves: 3) * amp * 0.08;
      final yb = level + follow + gully + wave;
      snow.lineTo(x, math.max(ry, yb));
    }
    snow.close();
    canvas.drawPath(
      snow,
      vertical(Rect.fromLTRB(0, top, w, level + amp * 0.3), [
        p.light,
        Color.lerp(p.light, p.snowShade, 0.22)!,
      ]),
    );
    canvas.save();
    canvas.clipPath(snow);
    canvas.drawPath(
      faces,
      fillPaint(Color.lerp(p.light, p.snowShade, style.snowShadeMix)!),
    );
    canvas.restore();
  }
  canvas.restore();
  return silhouette;
}

/// A ridgeline of conifer tips: the forest seen from across the valley.
Path treelinePath(
  RidgeLine ridge, {
  required double w,
  required double baseY,
  required double amp,
  required double bottom,
  required double tip,
  required int seed,
}) {
  final r = math.Random(seed);
  final p = Path()..moveTo(-ridge.margin, bottom);
  var x = -ridge.margin;
  p.lineTo(x, ridge.yAt(x, baseY, amp));
  while (x < w + ridge.margin) {
    final tw = tip * (0.55 + r.nextDouble() * 0.5);
    final th = tip * (0.9 + r.nextDouble() * 1.1);
    final y = ridge.yAt(x + tw / 2, baseY, amp);
    p
      ..lineTo(x, y)
      ..lineTo(x + tw * 0.5, y - th)
      ..lineTo(x + tw, y);
    x += tw * (0.55 + r.nextDouble() * 0.4);
  }
  p
    ..lineTo(w + ridge.margin, bottom)
    ..close();
  return p;
}

/// A cumulus: soft puffs, a flatter base, lit on top and toward the sun,
/// shaded underneath.
void paintCloud(
  Canvas canvas,
  Offset base,
  double width,
  BiomePalette p,
  int seed, {
  double opacity = 1,
  double flat = 0.5,
}) {
  final r = math.Random(seed);
  final n = 4 + r.nextInt(3);
  final baseH = width * (0.07 + 0.04 * (1 - flat));
  final puffs = <(Offset, double)>[];
  for (var i = 0; i < n; i++) {
    final t = n == 1 ? 0.5 : i / (n - 1);
    final bell = math.sin(t * math.pi);
    final rad =
        width *
        (0.07 + 0.13 * bell * (1 - flat * 0.6)) *
        (0.8 + r.nextDouble() * 0.4);
    final x =
        base.dx - width * 0.36 + width * 0.72 * t + (r.nextDouble() - 0.5) * 6;
    final y = math.min(base.dy - baseH - rad * 0.2 * (1 + bell), base.dy - rad);
    puffs.add((Offset(x, y), rad));
  }
  final shape =
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            base.dx - width / 2,
            base.dy - baseH * 1.6,
            base.dx + width / 2,
            base.dy,
          ),
          Radius.circular(baseH),
        ),
      );
  for (final (c, rad) in puffs) {
    shape.addOval(Rect.fromCircle(center: c, radius: rad));
  }
  final dir = p.lightFromLeft ? -1.0 : 1.0;
  canvas.drawPath(shape, fillPaint(p.cloudShade.withValues(alpha: opacity)));
  canvas.save();
  canvas.clipPath(shape);
  final lit = Path();
  for (final (c, rad) in puffs) {
    lit.addOval(
      Rect.fromCircle(
        center: c.translate(dir * rad * 0.16, -rad * 0.24),
        radius: rad * 0.96,
      ),
    );
  }
  lit.addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(
        base.dx - width / 2 + dir * 4,
        base.dy - baseH * 1.6 - 2,
        base.dx + width / 2 + dir * 4,
        base.dy - baseH * 0.75,
      ),
      Radius.circular(baseH),
    ),
  );
  canvas.drawPath(lit, fillPaint(p.cloudLit.withValues(alpha: opacity)));
  canvas.restore();
}

/// A bank of cloud along [y]: the seam where one unit's valley drops out
/// of sight and the next one's sky begins. [hangDown] draws it from
/// above (the top of a sky), otherwise from below (the foot of a valley).
void paintCloudBank(
  Canvas canvas,
  double w,
  double y,
  BiomePalette p,
  int seed, {
  required bool hangDown,
  double scale = 1,
}) {
  final r = math.Random(seed);
  final back = fillPaint(Color.lerp(p.mist, p.cloudShade, 0.55)!);
  final front = fillPaint(p.mist);
  for (final layer in [0, 1]) {
    final paint = layer == 0 ? back : front;
    final shift = layer == 0 ? 10.0 * scale : 0.0;
    final path = Path();
    var x = -20.0 + r.nextDouble() * 20;
    while (x < w + 40) {
      final rad = (16 + r.nextDouble() * 30) * scale;
      final cy =
          hangDown
              ? y + shift - rad * 0.2 + r.nextDouble() * 6
              : y - shift + rad * 0.2 - r.nextDouble() * 6;
      path.addOval(Rect.fromCircle(center: Offset(x, cy), radius: rad));
      x += rad * (1.1 + r.nextDouble() * 0.5);
    }
    path.addRect(
      hangDown
          ? Rect.fromLTRB(-10, y - 400, w + 10, y + shift)
          : Rect.fromLTRB(-10, y - shift, w + 10, y + 400),
    );
    canvas.drawPath(path, paint);
  }
}

/// Short strokes in two tones scattered over [area], skipping what
/// [keep] rejects: grain that keeps a flat fill from looking printed.
void paintGrain(
  Canvas canvas,
  Rect area,
  int seed, {
  required Color light,
  required Color dark,
  required double density,
  double length = 4,
  double angle = -math.pi / 2,
  double spread = 0.5,
  double width = 1.2,
  bool Function(Offset)? keep,
}) {
  final r = math.Random(seed);
  final count = (area.width * area.height * density / 1000).round();
  final a = Float32List(count * 4);
  final b = Float32List(count * 4);
  var na = 0, nb = 0;
  for (var i = 0; i < count; i++) {
    final x = area.left + r.nextDouble() * area.width;
    final y = area.top + r.nextDouble() * area.height;
    if (keep != null && !keep(Offset(x, y))) continue;
    final th = angle + (r.nextDouble() - 0.5) * spread * 2;
    final l = length * (0.5 + r.nextDouble());
    final dx = math.cos(th) * l, dy = math.sin(th) * l;
    if (r.nextBool()) {
      a
        ..[na++] = x
        ..[na++] = y
        ..[na++] = x + dx
        ..[na++] = y + dy;
    } else {
      b
        ..[nb++] = x
        ..[nb++] = y
        ..[nb++] = x + dx
        ..[nb++] = y + dy;
    }
  }
  Paint stroke(Color c) =>
      Paint()
        ..color = c
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
  canvas.drawRawPoints(PointMode.lines, a.sublist(0, na), stroke(light));
  canvas.drawRawPoints(PointMode.lines, b.sublist(0, nb), stroke(dark));
}
