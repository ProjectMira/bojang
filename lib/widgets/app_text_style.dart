import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_tokens.dart';

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
}
