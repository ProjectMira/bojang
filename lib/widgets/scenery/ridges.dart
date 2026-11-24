/// Ridgelines for the painted ranges: seeded fractal noise sampled once
/// in absolute pixels, so a range has the same scale on a phone and an
/// iPad (the iPad just sees more of it).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Seeded 1D value noise with smooth interpolation.
class Noise1D {
  Noise1D(int seed) : _v = _table(seed);

  final Float64List _v;

  static Float64List _table(int seed) {
    final r = math.Random(seed);
    final t = Float64List(256);
    for (var i = 0; i < 256; i++) {
      t[i] = r.nextDouble() * 2 - 1;
    }
    return t;
  }

  /// -1..1 at [x] (one unit is one lattice cell).
  double at(double x) {
    final i = x.floor();
    final f = x - i;
    final u = f * f * f * (f * (f * 6 - 15) + 10);
    final a = _v[i & 255], b = _v[(i + 1) & 255];
    return a + (b - a) * u;
  }

  /// Fractal sum of [octaves], roughly -1..1.
  double fbm(double x, {int octaves = 5, double gain = 0.5}) {
    var sum = 0.0, amp = 1.0, norm = 0.0, f = 1.0;
    for (var o = 0; o < octaves; o++) {
      sum += at(x * f + o * 17.31) * amp;
      norm += amp;
      amp *= gain;
      f *= 2.03;
    }
    return sum / norm;
  }

  /// Ridged fractal: sharp crests where the noise crosses zero, 0..1.
  double ridged(double x, {int octaves = 5, double gain = 0.5}) {
    var sum = 0.0, amp = 1.0, norm = 0.0, f = 1.0, weight = 1.0;
    for (var o = 0; o < octaves; o++) {
      var n = 1 - at(x * f + o * 31.7).abs();
      n *= n;
      n *= weight;
      weight = (n * 1.6).clamp(0.0, 1.0);
      sum += n * amp;
      norm += amp;
      amp *= gain;
      f *= 2.1;
    }
    return sum / norm;
  }
}

/// One range's ridgeline: heights 0..1 sampled every [step] px from
/// -[margin] to width + [margin].
class RidgeLine {
  RidgeLine._(this._h, this.step, this.margin);

  /// [wavelength] is the spacing of the big forms in px; [sharpness] mixes
  /// in ridged noise (0 rolling hills, 1 jagged peaks); [detail] is how
  /// much the small octaves break the line.
  factory RidgeLine.generate({
    required int seed,
    required double width,
    required double wavelength,
    double sharpness = 0.6,
    double detail = 0.5,
    double step = 3,
    double margin = 24,
    double floor = 0.0,
  }) {
    final noise = Noise1D(seed);
    final n = ((width + margin * 2) / step).ceil() + 2;
    final h = Float64List(n);
    final octaves = 3 + (detail * 4).round();
    final gain = 0.35 + detail * 0.25;
    var lo = double.infinity, hi = -double.infinity;
    for (var i = 0; i < n; i++) {
      final x = (i * step - margin) / wavelength;
      final soft = noise.fbm(x, octaves: octaves, gain: gain) * 0.5 + 0.5;
      final sharp = noise.ridged(x * 0.9 + 3.3, octaves: octaves, gain: gain);
      final v = soft * (1 - sharpness) + sharp * sharpness;
      h[i] = v;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    // Blunt the needles that the ridged octaves throw up: real summits
    // have shoulders.
    final passes = 3 + (sharpness * 5).round();
    final tmp = Float64List(n);
    for (var k = 0; k < passes; k++) {
      for (var i = 0; i < n; i++) {
        final a = h[math.max(0, i - 1)], b = h[math.min(n - 1, i + 1)];
        tmp[i] = (a + h[i] * 2 + b) / 4;
      }
      h.setAll(0, tmp);
    }
    lo = double.infinity;
    hi = -double.infinity;
    for (final v in h) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    // Normalise so every range uses its full height, then lift the
    // valleys to [floor] so the line never drops off the canvas.
    final span = math.max(1e-6, hi - lo);
    for (var i = 0; i < n; i++) {
      final v = (h[i] - lo) / span;
      h[i] = floor + (1 - floor) * v;
    }
    return RidgeLine._(h, step, margin);
  }

  final Float64List _h;
  final double step;
  final double margin;

  /// 0..1 at [x].
  double at(double x) {
    final f = (x + margin) / step;
    final i = f.floor().clamp(0, _h.length - 2);
    final t = (f - i).clamp(0.0, 1.0);
    return _h[i] + (_h[i + 1] - _h[i]) * t;
  }

  double yAt(double x, double baseY, double amp) => baseY - at(x) * amp;

  /// The filled silhouette closed down to [bottom].
  Path path({
    required double width,
    required double baseY,
    required double amp,
    required double bottom,
  }) {
    final p = Path()..moveTo(-margin, bottom);
    for (var x = -margin; x <= width + margin; x += step) {
      p.lineTo(x, yAt(x, baseY, amp));
    }
    p
      ..lineTo(width + margin, bottom)
      ..close();
    return p;
  }

  /// Local maxima across [width], highest first, at least [gap] px apart.
  List<double> peaks(double width, {double gap = 60, double minHeight = 0.3}) {
    final out = <(double, double)>[];
    for (var i = 2; i < _h.length - 2; i++) {
      final v = _h[i];
      if (v < minHeight) continue;
      if (v >= _h[i - 1] && v >= _h[i + 1] && v >= _h[i - 2] && v > _h[i + 2]) {
        final x = i * step - margin;
        if (x < -gap || x > width + gap) continue;
        out.add((x, v));
      }
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    final kept = <double>[];
    for (final (x, _) in out) {
      if (kept.every((k) => (k - x).abs() >= gap)) kept.add(x);
    }
    return kept;
  }

  /// The lowest point between [from] and [to].
  double lowest(double from, double to) {
    var bx = from, bv = double.infinity;
    final dir = to >= from ? 1.0 : -1.0;
    for (var x = from; dir > 0 ? x <= to : x >= to; x += step * dir) {
      final v = at(x);
      if (v < bv) {
        bv = v;
        bx = x;
      }
    }
    return bx;
  }

  /// The highest point between [from] and [to].
  double highest(double from, double to) {
    var bx = from, bv = -double.infinity;
    for (var x = from; x <= to; x += step) {
      final v = at(x);
      if (v > bv) {
        bv = v;
        bx = x;
      }
    }
    return bx;
  }
}
