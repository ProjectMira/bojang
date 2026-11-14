/// Ready-made ways to put the yak on a screen: talking ([YakSays]),
/// waiting ([YakLoader]) and explaining a dead end ([YakNotice]).
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import 'app_text_style.dart';
import 'yak_mascot.dart';

/// The yak with a speech bubble beside it.
class YakSays extends StatelessWidget {
  const YakSays({
    super.key,
    required this.title,
    this.body,
    this.mood = YakMood.happy,
    this.yakSize = 104,
    this.onTap,
  });

  YakSays.line(
    YakLine line, {
    super.key,
    this.yakSize = 104,
    this.onTap,
  }) : title = line.title,
       body = line.body,
       mood = line.mood;

  final String title;
  final String? body;
  final YakMood mood;
  final double yakSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bubble = CustomPaint(
      painter: _BubblePainter(
        fill: AppTokens.surface(context),
        border: AppTokens.cardBorder(context),
        shadow: AppTokens.isDark(context) ? null : Colors.black.withOpacity(0.06),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTextStyles.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTokens.ink(context),
                height: 1.35,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 2),
              Text(
                body!,
                style: AppTextStyles.poppins(
                  fontSize: 14,
                  color: AppTokens.inkSoft(context),
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        YakMascot(mood: mood, size: yakSize),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: bubble)),
      ],
    );

    return Semantics(
      container: true,
      label: '${YakLines.name} the yak says: $title ${body ?? ''}',
      excludeSemantics: true,
      button: onTap != null,
      child:
          onTap == null
              ? row
              : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: row,
              ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.fill, required this.border, this.shadow});

  final Color fill;
  final Color border;
  final Color? shadow;

  static const double _tail = 12;
  static const double _radius = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(_tail, 0, size.width - _tail, size.height),
      const Radius.circular(_radius),
    );
    final mid = size.height / 2;
    final tail =
        Path()
          ..moveTo(_tail + 1, mid - 9)
          ..lineTo(0, mid + 2)
          ..lineTo(_tail + 1, mid + 9)
          ..close();
    final path = Path.combine(
      PathOperation.union,
      Path()..addRRect(body),
      tail,
    );
    if (shadow != null) {
      canvas.drawPath(
        path.shift(const Offset(0, 4)),
        Paint()
          ..color = shadow!
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fill != fill || old.border != border || old.shadow != shadow;
}

/// Full-area waiting state: the yak thinking, with a line under it.
class YakLoader extends StatelessWidget {
  const YakLoader({super.key, this.message = YakLines.loading, this.size = 132});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message ?? 'Loading',
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            YakMascot(mood: YakMood.thinking, size: size),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTokens.inkSoft(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty and error states: the yak, what happened, and one way forward.
class YakNotice extends StatelessWidget {
  const YakNotice({
    super.key,
    required this.title,
    this.body,
    this.mood = YakMood.sad,
    this.actionLabel,
    this.onAction,
    this.size = 150,
  });

  YakNotice.line(
    YakLine line, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.size = 150,
  }) : title = line.title,
       body = line.body,
       mood = line.mood;

  final String title;
  final String? body;
  final YakMood mood;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            YakMascot(mood: mood, size: size),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTokens.ink(context),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppTextStyles.poppins(
                  fontSize: 14,
                  color: AppTokens.inkSoft(context),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
