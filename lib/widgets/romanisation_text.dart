import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/romanisation.dart';
import '../services/theme_service.dart';
import 'app_text_style.dart';

/// A Tibetan word's phonetics and/or Wylie, as the learner chose in
/// Settings > Reading. Shows nothing when the setting is off or the word has
/// no romanisation.
class RomanisationText extends StatelessWidget {
  final Romanisation value;

  /// Size of the phonetics line; Wylie is drawn a little smaller.
  final double fontSize;
  final TextAlign textAlign;
  final CrossAxisAlignment alignment;

  /// Overrides the learner's setting (tests, previews).
  final TransliterationMode? mode;

  const RomanisationText(
    this.value, {
    super.key,
    this.fontSize = 18,
    this.textAlign = TextAlign.center,
    this.alignment = CrossAxisAlignment.center,
    this.mode,
  });

  /// Readable on cards in both themes (the soft ink token is too light for
  /// text learners must read).
  static Color colorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFC5CDD6)
          : const Color(0xFF4A5868);

  @override
  Widget build(BuildContext context) {
    final selected = mode ?? context.watch<ThemeService>().transliterationMode;
    final showPhonetic = selected.showsPhonetics && value.phonetic.isNotEmpty;
    final showWylie = selected.showsWylie && value.wylie.isNotEmpty;
    if (!showPhonetic && !showWylie) return const SizedBox.shrink();
    final color = colorOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        if (showPhonetic)
          Text(
            value.phonetic,
            textAlign: textAlign,
            semanticsLabel: 'Pronounced ${value.phonetic}',
            style: AppTextStyles.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: color,
            ),
          ),
        if (showWylie)
          Text(
            value.wylie,
            textAlign: textAlign,
            semanticsLabel: 'Wylie ${value.wylie}',
            style: AppTextStyles.poppins(
              fontSize: showPhonetic ? fontSize * 0.8 : fontSize,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
      ],
    );
  }
}
