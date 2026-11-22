/// Shared design tokens: palette, tints, shape, spacing.
///
/// Screens should read colors through [AppTokens] (which resolves per
/// brightness) rather than hardcoding light-mode values, so every surface
/// stays correct in dark mode automatically.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bojang's palette comes from the five prayer-flag (lungta) colours: blue
/// for sky, white for air, red for fire, green for water and yellow for
/// earth. Every hue has the same four steps:
///
/// * **tint**: a very light fill for chips, banners and card backgrounds;
///   dark ink on it reads at 9:1 or more.
/// * **face**: the solid fill of a button or badge, and the accent on light
///   surfaces. White labels on blue, red, green and saffron faces reach at
///   least 4.5:1. The yellow face is too bright for white, so labels on it
///   use dark ink ([AppHue.onFace]).
/// * **lip**: the same hue, darker, drawn under a raised button face.
/// * **night**: the accent in dark mode (text, icons and rings on dark
///   surfaces), at least 4.5:1 against [backgroundDark] and [surfaceDark].
///
/// `test/theme/palette_contrast_test.dart` checks every pair, so a tweak
/// here that breaks contrast fails CI.
class AppColors {
  AppColors._();

  // Blue flag (sky). The brand colour: app bar, primary CTA, links.
  static const Color primary = Color(0xFF2174C8);

  /// The blue lip; also the deeper CTA fill.
  static const Color primaryDeep = Color(0xFF18579A);
  static const Color primaryTint = Color(0xFFE4EFFA);
  static const Color primaryNight = Color(0xFF6DAAE8);
  static const Color primaryNightTint = Color(0xFF16283B);

  /// Mid blue for borders on [primaryTint], e.g. a frozen streak day.
  static const Color primaryBorder = Color(0xFF9CC4EC);

  static const Color inkLight = Color(0xFF2C3E50);
  static const Color inkDark = Colors.white;
  static const Color inkSoftLight = Color(0xFF7F8C9B);
  static const Color inkSoftDark = Color(0xFF9AA4B0);

  // White flag (air): the neutral surfaces.
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF242A31);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  // Matches ThemeService's dark `scaffoldBackgroundColor` exactly so
  // screens that set this explicitly never show a seam against ones that
  // still rely on the global theme default.
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color whiteLip = Color(0xFFE3E7ED);

  // Green flag (water): correct answers, completion, progress.
  static const Color green = Color(0xFF1F844F);
  static const Color greenLip = Color(0xFF17643C);
  static const Color greenTint = Color(0xFFE3F3EA);
  static const Color greenNight = Color(0xFF43C281);
  static const Color greenNightTint = Color(0xFF15301F);

  /// The prayer flags have no orange. This is saffron, a warm step between
  /// the yellow and red flags, kept for the streak flame and other "warm"
  /// accents that used to be orange.
  static const Color orange = Color(0xFFC2550E);
  static const Color orangeLip = Color(0xFF92400A);
  static const Color orangeTint = Color(0xFFFCEBDF);
  static const Color orangeNight = Color(0xFFF2924F);
  static const Color orangeNightTint = Color(0xFF3A2313);

  /// The prayer flags have no purple either. This is lapis, the deeper,
  /// violet-leaning shade of the blue flag, so the fourth section accent
  /// stays distinct from [primary].
  static const Color purple = Color(0xFF606CCC);
  static const Color purpleLip = Color(0xFF3D49A6);
  static const Color purpleTint = Color(0xFFE9EBF8);
  static const Color purpleNight = Color(0xFF9DA6E3);
  static const Color purpleNightTint = Color(0xFF222540);

  // Yellow flag (earth): XP, rewards, results. Labels on it use dark ink.
  static const Color gold = Color(0xFFF2B807);
  static const Color goldLip = Color(0xFFC48D00);
  static const Color goldTint = Color(0xFFFDF3D3);
  static const Color goldNight = Color(0xFFF5C83A);
  static const Color goldNightTint = Color(0xFF382D10);

  // Red flag (fire): wrong answers, destructive actions, hearts.
  static const Color red = Color(0xFFD23C31);
  static const Color redLip = Color(0xFFA32B22);
  static const Color redTint = Color(0xFFFBE7E5);
  static const Color redNight = Color(0xFFEE8D85);
  static const Color redNightTint = Color(0xFF3A1D1B);
}

/// One palette hue with its four steps (see [AppColors]).
@immutable
class AppHue {
  final String name;
  final Color tint;
  final Color face;
  final Color lip;
  final Color night;
  final Color nightTint;

  /// Label colour on [face] (and [lip]).
  final Color onFace;

  const AppHue({
    required this.name,
    required this.tint,
    required this.face,
    required this.lip,
    required this.night,
    required this.nightTint,
    this.onFace = Colors.white,
  });

  /// Text on [tint], or on a chip filled with [face] at low opacity
  /// ([AppTokens.tint]), in light mode: the lip, or dark ink for hues that
  /// take dark labels (yellow's lip is too light to read on its tint).
  Color get textOnTint => onFace == Colors.white ? lip : onFace;
}

/// The palette as hues, for code that wants the structured steps.
class AppPalette {
  AppPalette._();

  static const AppHue blue = AppHue(
    name: 'blue',
    tint: AppColors.primaryTint,
    face: AppColors.primary,
    lip: AppColors.primaryDeep,
    night: AppColors.primaryNight,
    nightTint: AppColors.primaryNightTint,
  );

  static const AppHue white = AppHue(
    name: 'white',
    tint: AppColors.backgroundLight,
    face: AppColors.surfaceLight,
    lip: AppColors.whiteLip,
    night: AppColors.surfaceDark,
    nightTint: AppColors.backgroundDark,
    onFace: AppColors.inkLight,
  );

  static const AppHue red = AppHue(
    name: 'red',
    tint: AppColors.redTint,
    face: AppColors.red,
    lip: AppColors.redLip,
    night: AppColors.redNight,
    nightTint: AppColors.redNightTint,
  );

  static const AppHue green = AppHue(
    name: 'green',
    tint: AppColors.greenTint,
    face: AppColors.green,
    lip: AppColors.greenLip,
    night: AppColors.greenNight,
    nightTint: AppColors.greenNightTint,
  );

  static const AppHue yellow = AppHue(
    name: 'yellow',
    tint: AppColors.goldTint,
    face: AppColors.gold,
    lip: AppColors.goldLip,
    night: AppColors.goldNight,
    nightTint: AppColors.goldNightTint,
    onFace: AppColors.inkLight,
  );

  /// Derived roles for the old orange and purple names.
  static const AppHue saffron = AppHue(
    name: 'saffron',
    tint: AppColors.orangeTint,
    face: AppColors.orange,
    lip: AppColors.orangeLip,
    night: AppColors.orangeNight,
    nightTint: AppColors.orangeNightTint,
  );

  static const AppHue lapis = AppHue(
    name: 'lapis',
    tint: AppColors.purpleTint,
    face: AppColors.purple,
    lip: AppColors.purpleLip,
    night: AppColors.purpleNight,
    nightTint: AppColors.purpleNightTint,
  );

  /// The accent hue whose face is [face], or null for any other colour.
  static AppHue? ofFace(Color face) {
    for (final hue in all) {
      if (hue != white && hue.face == face) return hue;
    }
    return null;
  }

  /// The five flags in their traditional order, then the derived roles.
  static const List<AppHue> all = [
    blue,
    white,
    red,
    green,
    yellow,
    saffron,
    lapis,
  ];
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

  /// Status bar icon style for a screen whose header shows the page
  /// background (a transparent app bar). Without it the app-wide blue
  /// `appBarTheme` asks for white icons, which vanish on a light page.
  static SystemUiOverlayStyle statusBar(BuildContext context) =>
      isDark(context) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

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

  /// Text on a chip filled with [tint] of [accent]: [AppHue.textOnTint] in
  /// light mode, the night accent in dark mode; 4.5:1 or more either way.
  /// The face itself is not enough (gold on its tint is about 1.7:1).
  /// A colour outside the palette comes back unchanged.
  static Color textOnTint(Color accent, BuildContext context) {
    final hue = AppPalette.ofFace(accent);
    if (hue == null) return accent;
    return isDark(context) ? hue.night : hue.textOnTint;
  }

  /// [hue]'s accent for text and icons: the face on light surfaces, the
  /// night value on dark ones.
  static Color accent(AppHue hue, BuildContext context) =>
      isDark(context) ? hue.night : hue.face;

  /// [hue]'s banner/chip fill for the current brightness.
  static Color hueTint(AppHue hue, BuildContext context) =>
      isDark(context) ? hue.nightTint : hue.tint;

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
