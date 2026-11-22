import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_tokens.dart';
import '../theme/tibetan_type.dart';

class AppTextStyles {
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    List<Shadow>? shadows,
    FontStyle? fontStyle,
    double? height,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      shadows: shadows,
      fontStyle: fontStyle,
      height: height,
    ).copyWith(fontFamilyFallback: const ['Jomolhari']);
  }

  /// Screen headline, e.g. "Ready for Tibetan?".
  static TextStyle display(BuildContext context, {Color? color}) => poppins(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: color ?? AppTokens.ink(context),
  );

  /// Card/section titles.
  static TextStyle title(BuildContext context, {Color? color}) => poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: color ?? AppTokens.ink(context),
  );

  static TextStyle body(BuildContext context, {Color? color}) => poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: color ?? AppTokens.ink(context),
  );

  static TextStyle caption(BuildContext context, {Color? color}) => poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color ?? AppTokens.inkSoft(context),
  );

  /// Tibetan script: Jomolhari first, a 1.7 line height and never smaller
  /// than [TibetanType.minSize]. Use [TibetanText] when the text should
  /// shrink to fit its box.
  static TextStyle tibetan(
    BuildContext context, {
    double size = TibetanType.bodySize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) => TibetanType.style(
    size: size,
    weight: fontWeight,
    color: color ?? AppTokens.ink(context),
    height: height,
  );

  /// English text with Tibetan words inside it ("A tsheg (་) follows every
  /// syllable"): Poppins with Jomolhari fallback and room for the stacks.
  static TextStyle mixed(
    BuildContext context, {
    double fontSize = 15,
    FontWeight? fontWeight,
    Color? color,
  }) => poppins(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppTokens.ink(context),
    height: TibetanType.minLineHeight,
  );
}
