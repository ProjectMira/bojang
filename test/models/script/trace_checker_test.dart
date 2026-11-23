import 'dart:ui';

import 'package:bojang/models/script/stroke_data.dart';
import 'package:bojang/models/script/trace_checker.dart';
import 'package:flutter_test/flutter_test.dart';

List<Offset> _jitter(List<Offset> s, double d) => [
  for (var i = 0; i < s.length; i++) s[i] + Offset(i.isEven ? d : -d, d / 2),
];

void main() {
  const checker = TraceChecker();

  test('every consonant has strokes inside the box', () {
    expect(StrokeData.letters.length, 30);
    for (final ch in StrokeData.letters) {
      final strokes = StrokeData.of(ch)!;
      expect(strokes, isNotEmpty, reason: ch);
      for (final s in strokes) {
        expect(s.length, greaterThanOrEqualTo(2), reason: ch);
        for (final p in s) {
          expect(p.dx, inInclusiveRange(0, 100), reason: ch);
          expect(p.dy, inInclusiveRange(0, 100), reason: ch);
        }
      }
    }
  });

  test('resample spaces points evenly', () {
    final r = TraceChecker.resample(const [Offset(0, 0), Offset(10, 0)], 11);
    expect(r.length, 11);
    expect(r[5].dx, closeTo(5, 1e-9));
  });

  test('a stroke traced close to the line passes', () {
    final target = StrokeData.of('ཀ')!.last; // the long right stem
    final m = checker.matchStroke(_jitter(target, 3), target);
    expect(m.passed, isTrue);
    expect(m.coverage, greaterThan(0.9));
  });

  test('a stroke drawn backwards fails in guided mode only', () {
    final target = StrokeData.of('ཀ')!.last;
    final reversed = target.reversed.toList();
    expect(checker.matchStroke(reversed, target).passed, isFalse);
    expect(checker.matchStroke(reversed, target, checkDirection: false).passed, isTrue);
  });

  test('a short stub does not cover the stroke', () {
    final target = StrokeData.of('ཀ')!.last;
    final stub = [target.first, Offset.lerp(target.first, target.last, 0.3)!];
    final m = checker.matchStroke(stub, target);
    expect(m.passed, isFalse);
    expect(m.coverage, lessThan(0.7));
  });

  test('a stroke far from the line fails', () {
    final target = StrokeData.of('ཀ')!.last;
    final far = [for (final p in target) p + const Offset(-30, 0)];
    expect(checker.matchStroke(far, target).passed, isFalse);
  });

  test('freehand: the whole letter in any order passes', () {
    final strokes = StrokeData.of('ག')!;
    final drawn = [for (final s in strokes.reversed) _jitter(s, 2)];
    final r = checker.checkLetter(drawn, strokes);
    expect(r.passed, isTrue);
    expect(r.score, greaterThan(0.8));
  });

  test('freehand: a missing stroke or a different letter fails', () {
    final ka = StrokeData.of('ཀ')!;
    expect(checker.checkLetter(ka.sublist(0, ka.length - 1), ka).passed, isFalse);
    expect(checker.checkLetter(StrokeData.of('ཨ')!, ka).passed, isFalse);
  });

  test('freehand: an extra stroke fails (ཙ is ཅ plus a mark)', () {
    expect(checker.checkLetter(StrokeData.of('ཙ')!, StrokeData.of('ཅ')!).passed, isFalse);
  });

  test('freehand: a stray scribble fails', () {
    final ka = StrokeData.of('ཀ')!;
    final r = checker.checkLetter([...ka, const [Offset(90, 95), Offset(98, 99)]], ka);
    expect(r.passed, isFalse);
  });
}
