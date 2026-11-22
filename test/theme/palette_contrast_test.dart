import 'package:bojang/theme/app_tokens.dart';
import 'package:bojang/widgets/streak_day_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Hues that hold a solid accent; white is the neutral surface family.
  final accents = AppPalette.all.where((h) => h != AppPalette.white).toList();

  group('prayer-flag palette contrast', () {
    for (final hue in AppPalette.all) {
      test('${hue.name}: label on face reaches 4.5:1', () {
        expect(contrast(hue.onFace, hue.face), greaterThanOrEqualTo(4.5));
      });
    }

    for (final hue in accents) {
      test('${hue.name}: label on lip is at least the face ratio', () {
        expect(
          contrast(hue.onFace, hue.lip),
          hue.onFace == Colors.white
              ? greaterThanOrEqualTo(contrast(Colors.white, hue.face))
              : greaterThanOrEqualTo(3.0),
        );
      });

      test('${hue.name}: ink on tint reaches 4.5:1', () {
        expect(
          contrast(AppColors.inkLight, hue.tint),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('${hue.name}: white on night tint reaches 4.5:1', () {
        expect(
          contrast(Colors.white, hue.nightTint),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('${hue.name}: night accent reads on dark surfaces (4.5:1)', () {
        expect(
          contrast(hue.night, AppColors.surfaceDark),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(hue.night, AppColors.backgroundDark),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('${hue.name}: face still works as an icon in dark mode (3:1)', () {
        // Call sites use AppColors.<name> directly in both themes.
        expect(
          contrast(hue.face, AppColors.surfaceDark),
          greaterThanOrEqualTo(3.0),
        );
      });
    }

    test('white CTA labels: blue, red, green, saffron and lapis', () {
      for (final c in [
        AppColors.primary,
        AppColors.primaryDeep,
        AppColors.red,
        AppColors.green,
        AppColors.orange,
        AppColors.purple,
      ]) {
        expect(
          contrast(Colors.white, c),
          greaterThanOrEqualTo(4.5),
          reason: '$c',
        );
      }
    });

    test('yellow takes dark ink, not white', () {
      expect(AppPalette.yellow.onFace, AppColors.inkLight);
      expect(
        contrast(AppColors.inkLight, AppColors.gold),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('chip text on a tinted chip reaches 4.5:1 in both themes', () {
      // AppTokens.tint: the face at 10% (light) or 22% (dark) opacity over
      // the page or a card.
      Color chip(AppHue hue, Color under, double alpha) =>
          Color.alphaBlend(hue.face.withValues(alpha: alpha), under);
      for (final hue in accents) {
        for (final under in [AppColors.backgroundLight, AppColors.surfaceLight]) {
          expect(
            contrast(hue.textOnTint, chip(hue, under, 0.10)),
            greaterThanOrEqualTo(4.5),
            reason: '${hue.name} light',
          );
          expect(
            contrast(hue.textOnTint, hue.tint),
            greaterThanOrEqualTo(4.5),
            reason: '${hue.name} on tint',
          );
        }
        for (final under in [AppColors.backgroundDark, AppColors.surfaceDark]) {
          expect(
            contrast(hue.night, chip(hue, under, 0.22)),
            greaterThanOrEqualTo(4.5),
            reason: '${hue.name} dark',
          );
        }
      }
    });

    test('gold text takes dark ink on light fills', () {
      expect(AppPalette.ofFace(AppColors.gold), AppPalette.yellow);
      expect(AppPalette.yellow.textOnTint, AppColors.inkLight);
      expect(AppPalette.ofFace(AppColors.primary)!.textOnTint, AppColors.primaryDeep);
      expect(AppPalette.ofFace(const Color(0xFF123456)), isNull);
      // The face alone fails: this is what the "+20 XP" chip used to do.
      expect(
        contrast(AppColors.gold, AppColors.goldTint),
        lessThan(4.5),
      );
      expect(
        contrast(StreakColors.perfectText(false), AppColors.backgroundLight),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(StreakColors.perfectText(true), AppColors.backgroundDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('no Duolingo hex survives in the tokens', () {
      const old = {0xFF58CC02, 0xFFFF9600, 0xFFCE82FF, 0xFFFFC800, 0xFFFF4B4B};
      for (final hue in AppPalette.all) {
        for (final c in [
          hue.tint,
          hue.face,
          hue.lip,
          hue.night,
          hue.nightTint,
        ]) {
          expect(old.contains(c.toARGB32()), isFalse, reason: '${hue.name} $c');
        }
      }
    });
  });
}
