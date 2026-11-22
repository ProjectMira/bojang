import 'package:bojang/theme/motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Motion.resolve', () {
    test('defaults to full', () {
      expect(Motion.resolve(), MotionLevel.full);
    });

    test('the system setting wins over a "full" choice', () {
      expect(
        Motion.resolve(
          preference: AnimationPreference.full,
          systemDisableAnimations: true,
        ),
        MotionLevel.static,
      );
    });

    test('the learner can always ask for less', () {
      expect(
        Motion.resolve(preference: AnimationPreference.reduced),
        MotionLevel.reduced,
      );
      expect(
        Motion.resolve(preference: AnimationPreference.off),
        MotionLevel.static,
      );
      expect(
        Motion.resolve(preference: AnimationPreference.off, lowRamDevice: true),
        MotionLevel.static,
      );
    });

    test('a low-RAM phone drops to reduced, not static', () {
      expect(Motion.resolve(lowRamDevice: true), MotionLevel.reduced);
    });
  });

  group('Motion.isLowRam', () {
    test('OS low-RAM flag', () {
      expect(Motion.isLowRam(osLowRamFlag: true), isTrue);
    });

    test('threshold sits below a phone sold as 4 GB', () {
      expect(Motion.isLowRam(physicalRamMb: 1900), isTrue);
      expect(Motion.isLowRam(physicalRamMb: 2900), isTrue);
      expect(Motion.isLowRam(physicalRamMb: 3650), isFalse);
      expect(Motion.isLowRam(physicalRamMb: 7800), isFalse);
    });

    test('unknown RAM is not low', () {
      expect(Motion.isLowRam(), isFalse);
      expect(Motion.isLowRam(physicalRamMb: 0), isFalse);
    });
  });

  group('MotionLevel helpers', () {
    const d = Duration(milliseconds: 280);

    test('scale', () {
      expect(MotionLevel.full.scale(d), d);
      expect(MotionLevel.reduced.scale(d), const Duration(milliseconds: 140));
      expect(MotionLevel.static.scale(d), Duration.zero);
    });

    test('only full motion loops or celebrates', () {
      expect(MotionLevel.full.allowsLoops, isTrue);
      expect(MotionLevel.reduced.allowsLoops, isFalse);
      expect(MotionLevel.reduced.allowsCelebration, isFalse);
      expect(MotionLevel.reduced.animates, isTrue);
      expect(MotionLevel.static.animates, isFalse);
    });
  });

  test('AnimationPreference round-trips its id', () {
    for (final p in AnimationPreference.values) {
      expect(AnimationPreference.fromId(p.name), p);
    }
    expect(AnimationPreference.fromId(null), AnimationPreference.full);
    expect(AnimationPreference.fromId('bogus'), AnimationPreference.full);
  });

  testWidgets('Motion.of reads MediaQuery.disableAnimations', (tester) async {
    MotionLevel? seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            seen = Motion.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, MotionLevel.static);
  });
}
