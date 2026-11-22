/// Tibetan typography: the bundled Jomolhari face, tall lines for stacked
/// consonants and vowel signs, and a size floor that shrink-to-fit never
/// goes below.
///
/// Latin UI faces (Poppins) have no Tibetan glyphs, and many Android phones
/// ship weak Tibetan stacking, so Tibetan text always names Jomolhari first.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class TibetanType {
  TibetanType._();

  /// Declared in pubspec.yaml (assets/fonts/Jomolhari-Regular.ttf).
  static const String family = 'Jomolhari';

  /// Line height as a multiple of the font size. Superscripts, subscripts
  /// and vowel signs (gigu, naro, zhabkyu) need more room than Latin text.
  static const double lineHeight = 1.7;
  static const double minLineHeight = 1.6;
  static const double maxLineHeight = 1.8;

  /// The smallest Tibetan size the app shows. Below this, stacks such as
  /// བསྒྲུབས become hard to read on a phone.
  static const double minSize = 18;

  // The scale, largest first.
  static const double letterSize = 52; // a single letter on a lesson card
  static const double displaySize = 40; // the word being asked about
  static const double titleSize = 28; // a word on a card
  static const double bodySize = 22; // a phrase or sentence
  static const double smallSize = minSize; // captions, chips

  /// A Tibetan text style. [size] is clamped to at least [minSize] and
  /// [height] to the 1.6 to 1.8 range.
  static TextStyle style({
    double size = bodySize,
    FontWeight? weight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: math.max(size, minSize),
      fontWeight: weight,
      color: color,
      height: (height ?? lineHeight).clamp(minLineHeight, maxLineHeight),
    );
  }

  /// The size that fits [text] on one line in [maxWidth], shrinking from
  /// [size] but never below [floor] (and never growing). Text that still
  /// does not fit at the floor wraps instead.
  static double fittedSize({
    required String text,
    required double size,
    required double maxWidth,
    double floor = minSize,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final top = math.max(size, floor);
    if (!maxWidth.isFinite || text.isEmpty) return top;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style(size: top)),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width <= maxWidth) return top;
    // A little under the exact fit: glyph advances do not scale perfectly
    // linearly, and an exact fit can wrap the last syllable.
    return math.max(floor, top * maxWidth / width * 0.96);
  }
}

/// Tibetan text in [TibetanType] style that shrinks to fit its width, down
/// to [minSize] and no further; past that it wraps.
class TibetanText extends StatelessWidget {
  final String text;
  final double size;
  final double minSize;
  final FontWeight? weight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final String? semanticsLabel;

  const TibetanText(
    this.text, {
    super.key,
    this.size = TibetanType.bodySize,
    this.minSize = TibetanType.minSize,
    this.weight,
    this.color,
    this.textAlign,
    this.maxLines,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final floor = math.max(minSize, TibetanType.minSize);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fitted = TibetanType.fittedSize(
          text: text,
          size: size,
          maxWidth: constraints.maxWidth,
          floor: floor,
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
        return Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          softWrap: true,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          semanticsLabel: semanticsLabel,
          style: TibetanType.style(size: fitted, weight: weight, color: color),
        );
      },
    );
  }
}
