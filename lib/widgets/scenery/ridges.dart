/// Mountain ranges as silhouettes: seeded peaks in absolute x, so a range
/// looks the same size on a phone and an iPad (the iPad just sees more).
library;

import 'dart:math' as math;
import 'dart:ui';

class MountainRange {
  MountainRange._(this._xs, this._hs, this._ws, this._phases, this.smooth);

  /// Peaks every [spacing] px or so (±40%), heights between [minHeight]
  /// and 1, across [width] plus a margin on both sides.
  factory MountainRange.generate({
    required int seed,
    required double width,
    required double spacing,
    double minHeight = 0.4,
    bool smooth = false,
  }) {
    final r = math.Random(seed);
    final xs = <double>[];
    final hs = <double>[];
    final ws = <double>[];
    var x = -spacing * (0.5 + r.nextDouble());
    while (x < width + spacing * 1.5) {
      xs.add(x);
      hs.add(minHeight + (1 - minHeight) * r.nextDouble());
      ws.add(spacing * (0.8 + r.nextDouble() * 0.9));
      x += spacing * (0.6 + r.nextDouble() * 0.8);
    }
    final phases = [for (var i = 0; i < 3; i++) r.nextDouble() * math.pi * 2];
    return MountainRange._(xs, hs, ws, phases, smooth);
  }

  final List<double> _xs;
  final List<double> _hs;
  final List<double> _ws;
  final List<double> _phases;
  final bool smooth;

  int get peakCount => _xs.length;
  double peakX(int i) => _xs[i];
  double peakHeight(int i) => _hs[i];
  double peakWidth(int i) => _ws[i];

  /// 0..1 height at [x]; [jag] adds broken-rock noise.
  double at(double x, {double jag = 0}) {
    var h = 0.0;
    for (var i = 0; i < _xs.length; i++) {
      final t = (x - _xs[i]).abs() / _ws[i];
      if (t >= 1) continue;
      final shape =
          smooth
              ? math.pow(math.cos(t * math.pi / 2), 2).toDouble()
              : math.pow(1 - t, 1.2).toDouble();
      final v = _hs[i] * shape;
      if (v > h) h = v;
    }
    if (jag > 0) {
      h +=
          jag *
          (math.sin(x * 0.21 + _phases[0]) * 0.5 +
              math.sin(x * 0.57 + _phases[1]) * 0.3 +
              math.sin(x * 1.43 + _phases[2]) * 0.2);
    }
    return h;
  }

  /// The filled silhouette: ridge line at `baseY - at(x) * amp`, closed
  /// down to [bottom].
  Path path({
    required double width,
    required double baseY,
    required double amp,
    required double bottom,
    double jag = 0,
    double step = 4,
  }) {
    final p = Path()..moveTo(-2, bottom);
    for (var x = -2.0; x <= width + step; x += step) {
      p.lineTo(x, baseY - at(x, jag: jag) * amp);
    }
    p
      ..lineTo(width + step, bottom)
      ..close();
    return p;
  }

  /// The ridge height in px at [x].
  double yAt(double x, double baseY, double amp, {double jag = 0}) =>
      baseY - at(x, jag: jag) * amp;
}
