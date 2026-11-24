/// A board in the style of a Tibetan doorway: a whitewashed panel inside a
/// black frame, under a shambu, the pleated five-colour valance hung over
/// Tibetan doors and windows.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'props.dart';

/// The pleated valance alone: five-colour pleats with a scalloped hem
/// under a maroon lintel.
class ShambuPainter extends CustomPainter {
  const ShambuPainter({required this.dark, this.pleatWidth = 14});

  final bool dark;
  final double pleatWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final lintel = h * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, lintel),
        const Radius.circular(2),
      ),
      Paint()..color = dark ? const Color(0xFF4A1E18) : const Color(0xFF6E2A20),
    );
    final n = math.max(5, (w / pleatWidth).round());
    final pw = w / n;
    for (var i = 0; i < n; i++) {
      final x = i * pw;
      final base = kLungtaColors[i % 5];
      final color =
          dark ? Color.lerp(base, const Color(0xFF111B30), 0.35)! : base;
      final pleat =
          Path()
            ..moveTo(x, lintel - 0.5)
            ..lineTo(x + pw, lintel - 0.5)
            ..lineTo(x + pw, h - pw * 0.35)
            ..quadraticBezierTo(x + pw / 2, h + pw * 0.15, x, h - pw * 0.35)
            ..close();
      canvas.drawPath(pleat, Paint()..color = color);
      // The fold: darker on the right of each pleat.
      canvas.drawRect(
        Rect.fromLTWH(x + pw * 0.62, lintel, pw * 0.38, h - lintel - pw * 0.3),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(ShambuPainter old) =>
      old.dark != dark || old.pleatWidth != pleatWidth;
}

class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.panel,
    required this.frame,
    required this.border,
    this.flare = 10,
  });

  final Color panel;
  final Color frame;
  final double border;
  final double flare;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // The frame flares a little at the foot, like a Tibetan window.
    final flare = math.min(this.flare, w * 0.03);
    final outer =
        Path()
          ..moveTo(flare, 0)
          ..lineTo(w - flare, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawShadow(outer, const Color(0xFF000000), 3, false);
    canvas.drawPath(outer, Paint()..color = frame);
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(flare + border, border, w - flare - border, h - border),
      const Radius.circular(3),
    );
    canvas.drawRRect(inner, Paint()..color = panel);
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.panel != panel ||
      old.frame != frame ||
      old.border != border ||
      old.flare != flare;
}

/// A whitewashed board in a black flared frame under a shambu. The child
/// sits on the panel; text on it uses [SignboardColors].
class Signboard extends StatelessWidget {
  const Signboard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 16),
    this.compact = false,
  });

  final Widget child;
  final EdgeInsets padding;

  /// A slim board for unit names: thinner frame and valance, tight
  /// padding, so it names the place without hiding it.
  final bool compact;

  static const double border = 6;
  static const double shambuHeight = 20;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final colors = SignboardColors.of(context);
    final frame = compact ? 3.5 : border;
    final inset = compact ? const EdgeInsets.fromLTRB(12, 7, 12, 8) : padding;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 4),
          child: SizedBox(
            height: compact ? 11 : shambuHeight,
            child: CustomPaint(
              painter: ShambuPainter(dark: dark, pleatWidth: compact ? 10 : 14),
            ),
          ),
        ),
        CustomPaint(
          painter: _FramePainter(
            panel: colors.panel,
            frame: colors.frame,
            border: frame,
            flare: compact ? 5 : 10,
          ),
          child: Padding(
            padding:
                inset +
                EdgeInsets.symmetric(
                  horizontal: frame + (compact ? 4 : 6),
                  vertical: frame,
                ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The panel, frame and text colours of a [Signboard].
class SignboardColors {
  const SignboardColors({
    required this.panel,
    required this.frame,
    required this.ink,
    required this.inkSoft,
  });

  final Color panel;
  final Color frame;
  final Color ink;

  /// Secondary text; still 4.5:1 or more on [panel].
  final Color inkSoft;

  static SignboardColors of(BuildContext context) =>
      AppTokens.isDark(context)
          ? const SignboardColors(
            panel: Color(0xFF1E2532),
            frame: Color(0xFF07090D),
            ink: Color(0xFFF4F6FA),
            inkSoft: Color(0xFFAFB8C7),
          )
          : const SignboardColors(
            panel: Color(0xFFFBFAF7),
            frame: Color(0xFF23211E),
            ink: AppColors.inkLight,
            inkSoft: Color(0xFF5E6A78),
          );
}
