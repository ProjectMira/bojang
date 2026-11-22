import 'package:flutter/material.dart';

import '../utils/streak_rules.dart';

/// The streak flame, drawn in code so it can grow with the streak: each
/// [FlameTier] (7, 14, 30 and 50 days) is a little taller and changes
/// colour, the Blaze grows side tongues and the Golden flame burns gold with
/// a blue heart, like a butter lamp.
///
/// With [from], the flame grows from that tier into [tier] once (the tier
/// celebration); with Reduce Motion it shows [tier] straight away.
class StreakFlame extends StatefulWidget {
  const StreakFlame({
    super.key,
    required this.tier,
    required this.size,
    this.from,
    this.dimmed = false,
  });

  final FlameTier tier;

  /// The box the largest tier fills; smaller tiers sit inside it.
  final double size;
  final FlameTier? from;

  /// A preview of a tier not reached yet.
  final bool dimmed;

  /// The tier's main colour, for text and accents next to the flame.
  static Color accent(FlameTier tier) => _palette(tier).outer.last;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _FlamePalette {
  const _FlamePalette(this.outer, this.core, this.scale, {this.heart});
  final List<Color> outer;
  final Color core;
  final Color? heart;
  final double scale;
}

_FlamePalette _palette(FlameTier tier) => switch (tier) {
  FlameTier.spark => const _FlamePalette(
    [Color(0xFFFFCF4D), Color(0xFFFF9600)],
    Color(0xFFFFF4C9),
    0.70,
  ),
  FlameTier.flame => const _FlamePalette(
    [Color(0xFFFFB627), Color(0xFFFF6A00)],
    Color(0xFFFFE28F),
    0.80,
  ),
  FlameTier.blaze => const _FlamePalette(
    [Color(0xFFFF9A1F), Color(0xFFE8421B)],
    Color(0xFFFFD35C),
    0.90,
  ),
  FlameTier.bonfire => const _FlamePalette(
    [Color(0xFFFF7A3D), Color(0xFFC2185B)],
    Color(0xFFFFB84D),
    0.96,
  ),
  FlameTier.golden => const _FlamePalette(
    [Color(0xFFFFE38A), Color(0xFFE0A100)],
    Color(0xFFFFFBEA),
    1.0,
    heart: Color(0xFF5AA9E6),
  ),
};

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  AnimationController? _grow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.from != null && widget.from != widget.tier && !reduceMotion) {
      _grow ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..forward();
    }
  }

  @override
  void dispose() {
    _grow?.dispose();
    super.dispose();
  }

  Widget _paint(FlameTier tier, double opacity) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _FlamePainter(_palette(tier), tier, dimmed: widget.dimmed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grow = _grow;
    final flame =
        grow == null
            ? _paint(widget.tier, 1)
            : AnimatedBuilder(
              animation: grow,
              builder: (context, _) {
                // The old flame fades as the new one swells past full size
                // and settles.
                final t = Curves.easeOut.transform(grow.value);
                final swell = TweenSequence<double>([
                  TweenSequenceItem(
                    tween: Tween(begin: 0.85, end: 1.12),
                    weight: 60,
                  ),
                  TweenSequenceItem(
                    tween: Tween(begin: 1.12, end: 1.0),
                    weight: 40,
                  ),
                ]).transform(grow.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _paint(widget.from!, 1 - t),
                    Transform.scale(
                      scale: swell,
                      alignment: Alignment.bottomCenter,
                      child: _paint(widget.tier, t),
                    ),
                  ],
                );
              },
            );
    return Semantics(
      label: '${widget.tier.label} streak flame',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(dimension: widget.size, child: flame),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter(this.palette, this.tier, {required this.dimmed});

  final _FlamePalette palette;
  final FlameTier tier;
  final bool dimmed;

  /// A flame tongue in the box [r]: a teardrop with the tip at the top.
  Path _tongue(Rect r) {
    final w = r.width, h = r.height, x = r.left, y = r.top;
    return Path()
      ..moveTo(x + 0.5 * w, y)
      ..cubicTo(
        x + 0.62 * w,
        y + 0.22 * h,
        x + 0.95 * w,
        y + 0.40 * h,
        x + 0.90 * w,
        y + 0.68 * h,
      )
      ..cubicTo(
        x + 0.86 * w,
        y + 0.90 * h,
        x + 0.68 * w,
        y + h,
        x + 0.5 * w,
        y + h,
      )
      ..cubicTo(
        x + 0.32 * w,
        y + h,
        x + 0.14 * w,
        y + 0.90 * h,
        x + 0.10 * w,
        y + 0.68 * h,
      )
      ..cubicTo(
        x + 0.05 * w,
        y + 0.40 * h,
        x + 0.38 * w,
        y + 0.22 * h,
        x + 0.5 * w,
        y,
      )
      ..close();
  }

  Paint _fill(Rect r, List<Color> colors) {
    final c =
        dimmed ? colors.map((c) => c.withValues(alpha: 0.35)).toList() : colors;
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: c,
      ).createShader(r);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width * palette.scale;
    // Anchored to the bottom centre, so a bigger tier grows upward.
    final body = Rect.fromLTWH(
      (size.width - s * 0.78) / 2,
      size.height - s,
      s * 0.78,
      s,
    );

    if (tier == FlameTier.golden && !dimmed) {
      canvas.drawCircle(
        body.center.translate(0, s * 0.08),
        s * 0.52,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE38A).withValues(alpha: 0.45),
              const Color(0xFFFFE38A).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(center: body.center, radius: s * 0.52),
          ),
      );
    }

    if (tier.index >= FlameTier.blaze.index) {
      // Side tongues, leaning out.
      final side = Size(body.width * 0.5, body.height * 0.55);
      for (final dir in [-1.0, 1.0]) {
        canvas.save();
        final anchor = Offset(
          body.center.dx + dir * body.width * 0.30,
          body.bottom - side.height * 0.15,
        );
        canvas.translate(anchor.dx, anchor.dy);
        canvas.rotate(dir * 0.42);
        final r = Rect.fromLTWH(
          -side.width / 2,
          -side.height,
          side.width,
          side.height,
        );
        canvas.drawPath(_tongue(r), _fill(r, palette.outer));
        canvas.restore();
      }
    }

    canvas.drawPath(_tongue(body), _fill(body, palette.outer));

    final core = Rect.fromLTWH(
      body.left + body.width * 0.27,
      body.top + body.height * 0.42,
      body.width * 0.46,
      body.height * 0.52,
    );
    final coreColors = [
      palette.core,
      palette.heart ?? palette.core.withValues(alpha: 0.85),
    ];
    canvas.drawPath(_tongue(core), _fill(core, coreColors));
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.tier != tier || old.dimmed != dimmed;
}
