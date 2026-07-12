/// Shared design tokens: palette, tints, shape, spacing.
///
/// Screens should read colors through [AppTokens] (which resolves per
/// brightness) rather than hardcoding light-mode values, so every surface
/// stays correct in dark mode automatically.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2C97DD);
  static const Color primaryDeep = Color(0xFF1976D2);

  static const Color inkLight = Color(0xFF2C3E50);
  static const Color inkDark = Colors.white;
  static const Color inkSoftLight = Color(0xFF7F8C9B);
  static const Color inkSoftDark = Color(0xFF9AA4B0);

  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF242A31);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  // Matches ThemeService's dark `scaffoldBackgroundColor` exactly so
  // screens that set this explicitly never show a seam against ones that
  // still rely on the global theme default.
  static const Color backgroundDark = Color(0xFF1A1A1A);

  static const Color green = Color(0xFF58CC02);
  static const Color orange = Color(0xFFFF9600);
  static const Color purple = Color(0xFFCE82FF);
  static const Color gold = Color(0xFFFFC800);
  static const Color red = Color(0xFFFF4B4B);
}

/// Section accent cycle used by the categories page and home shortcuts.
const List<Color> kSectionColors = [
  AppColors.primary,
  AppColors.green,
  AppColors.purple,
  AppColors.orange,
];

class AppTokens {
  AppTokens._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color ink(BuildContext context) =>
      isDark(context) ? AppColors.inkDark : AppColors.inkLight;

  static Color inkSoft(BuildContext context) =>
      isDark(context) ? AppColors.inkSoftDark : AppColors.inkSoftLight;

  static Color surface(BuildContext context) =>
      isDark(context) ? AppColors.surfaceDark : AppColors.surfaceLight;

  static Color background(BuildContext context) =>
      isDark(context) ? AppColors.backgroundDark : AppColors.backgroundLight;

  /// Tint a brand/accent color for chip and card backgrounds.
  static Color tint(Color color, BuildContext context, {double? opacity}) {
    return color.withOpacity(opacity ?? (isDark(context) ? 0.22 : 0.10));
  }

  static Color divider(BuildContext context) =>
      isDark(context)
          ? Colors.white.withOpacity(0.10)
          : AppColors.inkSoftLight.withOpacity(0.15);

  static Color cardBorder(BuildContext context) =>
      isDark(context)
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.06);

  /// Single shared shadow. Dark mode relies on [cardBorder] instead, so this
  /// returns an empty list there — flat cards read better than muddy shadows
  /// on dark backgrounds.
  static List<BoxShadow> shadow(BuildContext context) {
    if (isDark(context)) return const [];
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// The one place allowed a colored shadow — the primary lesson CTA.
  static List<BoxShadow> heroShadow(BuildContext context) {
    return [
      BoxShadow(
        color: AppColors.primary.withOpacity(isDark(context) ? 0.35 : 0.25),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }
}

class AppRadius {
  AppRadius._();
  static const double chip = 12;
  static const double card = 16;
  static const double hero = 20;
  static const double button = 28;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Screen edge gutter.
  static const double gutter = 20;

  /// Vertical gap between major sections on a screen.
  static const double section = 28;
}
