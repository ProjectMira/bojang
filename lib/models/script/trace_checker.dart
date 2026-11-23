/// Tolerance-based checking of a traced or freehand letter against its
/// stroke paths (see [StrokeData]). Pure geometry, so it runs on the device
/// and is unit-tested; the server trusts its verdict (`graded_by=client`).
///
/// Coordinates are in the 100 x 100 stroke box. A drawn stroke matches a
/// target stroke when, after both are resampled to evenly spaced points:
///
/// * on average the drawing stays within [tolerance] of the target
///   (closeness), and
/// * at least [minCoverage] of the target's points have the drawing within
///   [tolerance] x 1.5 (it was drawn all the way, not just touched), and
/// * in guided mode, it starts nearer the target's start than its end
///   (the right direction).
library;

import 'dart:math' as math;
import 'dart:ui';

class StrokeMatch {
  const StrokeMatch({
    required this.closeness,
    required this.coverage,
    required this.rightDirection,
    required this.passed,
  });

  /// Mean distance from the drawing to the target, in box units.
  final double closeness;

  /// Share of the target that the drawing passed near (0-1).
  final double coverage;
  final bool rightDirection;
  final bool passed;

  /// 0-1, higher is better: coverage, less a penalty for wandering.
  double get score =>
      (coverage - math.max(0, closeness - 4) / 40).clamp(0.0, 1.0).toDouble();
}

class LetterResult {
  const LetterResult(this.matches, {required this.passed});

  /// Per target stroke, the best drawn stroke's match (null: none drawn).
  final List<StrokeMatch?> matches;
  final bool passed;

  double get score {
    if (matches.isEmpty) return 0;
    var total = 0.0;
    for (final m in matches) {
      total += m?.score ?? 0;
    }
    return total / matches.length;
  }
}

class TraceChecker {
  const TraceChecker({
    this.tolerance = 7,
    this.minCoverage = 0.7,
    this.samples = 24,
  });

  /// How far (box units, of 100) a drawing may stray from a stroke.
  final double tolerance;
  final double minCoverage;
  final int samples;

  /// [points] resampled to [count] evenly spaced points along its length.
  static List<Offset> resample(List<Offset> points, int count) {
    if (points.isEmpty) return const [];
    if (points.length == 1 || count < 2) {
      return List.filled(math.max(count, 1), points.first);
    }
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
    }
    final total = lengths.last;
    if (total == 0) return List.filled(count, points.first);
    final out = <Offset>[];
    var seg = 1;
    for (var k = 0; k < count; k++) {
      final target = total * k / (count - 1);
      while (seg < points.length - 1 && lengths[seg] < target) {
        seg++;
      }
      final a = points[seg - 1], b = points[seg];
      final span = lengths[seg] - lengths[seg - 1];
      final t = span == 0 ? 0.0 : (target - lengths[seg - 1]) / span;
      out.add(Offset.lerp(a, b, t.clamp(0.0, 1.0))!);
    }
    return out;
  }

  /// Distance from [p] to the polyline [line].
  static double distanceToPolyline(Offset p, List<Offset> line) {
    if (line.isEmpty) return double.infinity;
    if (line.length == 1) return (p - line.first).distance;
    var best = double.infinity;
    for (var i = 1; i < line.length; i++) {
      best = math.min(best, _distanceToSegment(p, line[i - 1], line[i]));
    }
    return best;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// Checks one drawn stroke against one target stroke.
  StrokeMatch matchStroke(
    List<Offset> drawn,
    List<Offset> target, {
    bool checkDirection = true,
  }) {
    if (drawn.length < 2 || target.length < 2) {
      return const StrokeMatch(
        closeness: double.infinity,
        coverage: 0,
        rightDirection: false,
        passed: false,
      );
    }
    final d = resample(drawn, samples);
    final t = resample(target, samples);
    var sum = 0.0;
    for (final p in d) {
      sum += distanceToPolyline(p, target);
    }
    final closeness = sum / d.length;
    var covered = 0;
    for (final p in t) {
      if (distanceToPolyline(p, drawn) <= tolerance * 1.5) covered++;
    }
    final coverage = covered / t.length;
    final rightDirection =
        (d.first - t.first).distance <= (d.first - t.last).distance;
    final passed =
        closeness <= tolerance &&
        coverage >= minCoverage &&
        (!checkDirection || rightDirection);
    return StrokeMatch(
      closeness: closeness,
      coverage: coverage,
      rightDirection: rightDirection,
      passed: passed,
    );
  }

  /// A freehand letter: every target stroke must be matched by its own
  /// drawn stroke (in any order; direction is not checked), and no drawn
  /// stroke may stray from the letter. Strokes are paired greedily, best
  /// match first, each drawn stroke used once.
  LetterResult checkLetter(
    List<List<Offset>> drawn,
    List<List<Offset>> target,
  ) {
    final usable = [for (final s in drawn) if (s.length >= 2) s];
    final pairs = <(int, int, StrokeMatch)>[];
    for (var ti = 0; ti < target.length; ti++) {
      for (var di = 0; di < usable.length; di++) {
        pairs.add((ti, di, matchStroke(usable[di], target[ti], checkDirection: false)));
      }
    }
    pairs.sort((a, b) {
      final pass = (b.$3.passed ? 1 : 0) - (a.$3.passed ? 1 : 0);
      return pass != 0 ? pass : b.$3.score.compareTo(a.$3.score);
    });
    final matches = List<StrokeMatch?>.filled(target.length, null);
    final usedDrawn = <int>{};
    for (final (ti, di, m) in pairs) {
      if (matches[ti] != null || usedDrawn.contains(di)) continue;
      matches[ti] = m;
      usedDrawn.add(di);
    }
    final strays = usable.where((s) {
      final mean =
          resample(s, samples)
              .map((p) => _distanceToLetter(p, target))
              .reduce((a, b) => a + b) /
          samples;
      return mean > tolerance * 1.5;
    });
    // A drawn stroke left over (more strokes than the letter has) fails,
    // unless it is a dot-sized slip.
    final leftovers = [
      for (var di = 0; di < usable.length; di++)
        if (!usedDrawn.contains(di) && _length(usable[di]) > 5) di,
    ];
    final passed =
        target.isNotEmpty &&
        matches.every((m) => m != null && m.passed) &&
        strays.isEmpty &&
        leftovers.isEmpty;
    return LetterResult(matches, passed: passed);
  }

  static double _length(List<Offset> s) {
    var total = 0.0;
    for (var i = 1; i < s.length; i++) {
      total += (s[i] - s[i - 1]).distance;
    }
    return total;
  }

  /// Distance from [p] to the nearest stroke of a letter.
  static double _distanceToLetter(Offset p, List<List<Offset>> strokes) {
    var best = double.infinity;
    for (final s in strokes) {
      best = math.min(best, distanceToPolyline(p, s));
    }
    return best;
  }
}
