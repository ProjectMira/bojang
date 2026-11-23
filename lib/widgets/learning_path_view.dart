import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/learning_path.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tibetan_type.dart';
import 'app_text_style.dart';
import 'content_width.dart';

/// The learning path drawn as units of round steps that wind down the page.
/// The active step wears its session ring and the one big Start button.
///
/// Rendering only: [onOpen] runs for a reachable step, [onLocked] for a
/// locked one (show why).
class LearningPathView extends StatelessWidget {
  const LearningPathView({
    super.key,
    required this.path,
    required this.onOpen,
    required this.onLocked,
    this.activeKey,
  });

  /// Put on the active step, so the page can scroll it into view.
  final Key? activeKey;

  final LearningPath path;
  final void Function(PathNode node) onOpen;
  final void Function(PathNode node) onLocked;

  /// The prayer-flag hues, one per unit in turn.
  static const List<AppHue> unitHues = [
    AppPalette.blue,
    AppPalette.green,
    AppPalette.red,
    AppPalette.yellow,
    AppPalette.lapis,
    AppPalette.saffron,
  ];

  static AppHue hueOf(PathUnit unit) =>
      unitHues[(unit.index - 1).abs() % unitHues.length];

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final unit in path.units) ...[
          PathUnitHeader(unit: unit, hue: hueOf(unit)),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < unit.nodes.length; i++)
            _WindingRow(
              index: i,
              tablet: tablet,
              child: PathNodeButton(
                key: unit.nodes[i].isActive ? activeKey : null,
                node: unit.nodes[i],
                hue: hueOf(unit),
                size: tablet ? 92 : 72,
                onTap: () {
                  final node = unit.nodes[i];
                  node.isLocked ? onLocked(node) : onOpen(node);
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ],
    );
  }
}

/// Offsets each step left or right along a gentle wave.
class _WindingRow extends StatelessWidget {
  const _WindingRow({
    required this.index,
    required this.tablet,
    required this.child,
  });

  final int index;
  final bool tablet;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final swing = tablet ? 120.0 : 70.0;
    final dx = math.sin(index * math.pi / 3) * swing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: Center(child: child),
      ),
    );
  }
}

class PathUnitHeader extends StatelessWidget {
  const PathUnitHeader({super.key, required this.unit, required this.hue});

  final PathUnit unit;
  final AppHue hue;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final locked = unit.isLocked;
    final face = dark ? hue.night : hue.face;
    final fill = locked ? AppTokens.surface(context) : face;
    final onFill =
        locked
            ? AppTokens.inkSoft(context)
            : (dark ? AppColors.inkLight : hue.onFace);
    final lessons = unit.nodes.length;
    return Semantics(
      header: true,
      label:
          'Unit ${unit.index}, ${unit.title}. ${unit.passedCount} of $lessons steps done'
          '${locked ? ', locked' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.hero),
          border:
              locked ? Border.all(color: AppTokens.cardBorder(context)) : null,
          boxShadow:
              locked
                  ? null
                  : [
                    BoxShadow(
                      color: (dark ? hue.nightTint : hue.lip),
                      offset: const Offset(0, 4),
                    ),
                  ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UNIT ${unit.index}',
                    style: AppTextStyles.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: onFill.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unit.title,
                    style: AppTextStyles.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: onFill,
                    ),
                  ),
                  if (unit.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      unit.description,
                      style: AppTextStyles.poppins(
                        fontSize: 13,
                        color: onFill.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${unit.passedCount}/$lessons',
              style: AppTextStyles.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: onFill,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// One round step. Passed steps are gold with a check, the active one wears
/// its session ring and a Start button under it, locked ones are grey.
class PathNodeButton extends StatefulWidget {
  const PathNodeButton({
    super.key,
    required this.node,
    required this.hue,
    required this.onTap,
    this.size = 72,
  });

  final PathNode node;
  final AppHue hue;
  final VoidCallback onTap;
  final double size;

  @override
  State<PathNodeButton> createState() => _PathNodeButtonState();
}

class _PathNodeButtonState extends State<PathNodeButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loops = Motion.of(context).allowsLoops;
    if (widget.node.isActive && loops) {
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat(reverse: true);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.node.type) {
    PathNodeType.practice => Icons.fitness_center_rounded,
    PathNodeType.unitReview => Icons.emoji_events_rounded,
    PathNodeType.dialogue => Icons.forum_rounded,
    PathNodeType.alphabetGate => Icons.menu_book_rounded,
    _ => Icons.star_rounded,
  };

  /// Script steps show a letter instead of an icon.
  bool get _showsLetter =>
      widget.node.type == PathNodeType.alphabet ||
      widget.node.subtype == 'script' &&
          widget.node.type == PathNodeType.lesson;

  String get _stateLabel => switch (widget.node.state) {
    PathNodeState.locked => 'locked',
    PathNodeState.unlocked => 'open',
    PathNodeState.active =>
      'next up, session ${widget.node.finishedSessions + 1} of ${widget.node.totalSessions}',
    PathNodeState.passed => 'done',
  };

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final dark = AppTokens.isDark(context);
    final hue = widget.hue;
    final size = widget.size;

    final Color face;
    final Color lip;
    final Color ink;
    switch (node.state) {
      case PathNodeState.passed:
        face = dark ? AppColors.goldNight : AppColors.gold;
        lip = AppColors.goldLip;
        ink = AppColors.inkLight;
      case PathNodeState.locked:
        face = dark ? AppColors.surfaceDark : AppColors.whiteLip;
        lip =
            dark ? Colors.black : AppColors.inkSoftLight.withValues(alpha: 0.5);
        ink = AppTokens.inkSoft(context);
      case PathNodeState.active:
      case PathNodeState.unlocked:
        face = dark ? hue.night : hue.face;
        lip = dark ? hue.nightTint : hue.lip;
        ink = dark ? AppColors.inkLight : hue.onFace;
    }

    final Widget glyph =
        node.isLocked
            ? Icon(Icons.lock_rounded, color: ink, size: size * 0.38)
            : node.isPassed
            ? Icon(Icons.check_rounded, color: ink, size: size * 0.48)
            : _showsLetter
            ? Text(
              'ཀ',
              style: TibetanType.style(
                size: size * 0.42,
                color: ink,
                height: 1.6,
              ),
            )
            : Icon(_icon, color: ink, size: size * 0.44);

    final ringGap = size * 0.14;
    final disc = AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: Motion.of(context).scale(const Duration(milliseconds: 120)),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: face,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: lip, offset: Offset(0, size * 0.08))],
        ),
        child: glyph,
      ),
    );

    Widget body = SizedBox(
      width: size + ringGap * 2,
      height: size + ringGap * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (node.isActive ||
              (node.state == PathNodeState.unlocked &&
                  node.finishedSessions > 0))
            SessionRing(
              size: size + ringGap * 2,
              progress: node.progress,
              color: dark ? hue.night : hue.face,
              track: AppTokens.tint(
                dark ? hue.night : hue.face,
                context,
                opacity: dark ? 0.25 : 0.18,
              ),
            ),
          disc,
        ],
      ),
    );

    final pulse = _pulse;
    if (pulse != null) {
      body = AnimatedBuilder(
        animation: pulse,
        builder:
            (context, child) => Transform.scale(
              scale: 1 + 0.035 * Curves.easeInOut.transform(pulse.value),
              child: child,
            ),
        child: body,
      );
    }

    return Semantics(
      button: true,
      label: '${node.title}, $_stateLabel',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: body,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size * 2.4),
            child: Text(
              node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.poppins(
                fontSize: size > 80 ? 14 : 13,
                fontWeight: node.isActive ? FontWeight.w700 : FontWeight.w500,
                color:
                    node.isLocked
                        ? AppTokens.inkSoft(context)
                        : AppTokens.ink(context),
              ),
            ),
          ),
          if (node.isActive) ...[
            const SizedBox(height: AppSpacing.sm),
            _StartButton(
              hue: hue,
              sessionLabel:
                  node.totalSessions > 1
                      ? '${node.finishedSessions}/${node.totalSessions}'
                      : null,
              onTap: widget.onTap,
              wide: size > 80,
            ),
          ],
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.hue,
    required this.onTap,
    this.sessionLabel,
    this.wide = false,
  });

  final AppHue hue;
  final VoidCallback onTap;
  final String? sessionLabel;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final face = dark ? hue.night : hue.face;
    final ink = dark ? AppColors.inkLight : hue.onFace;
    return ExcludeSemantics(
      child: Material(
        color: face,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          key: const ValueKey('path_start_button'),
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(
              minHeight: 48,
              minWidth: wide ? 180 : 150,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              boxShadow: [
                BoxShadow(
                  color: dark ? hue.nightTint : hue.lip,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Start',
                  style: AppTextStyles.poppins(
                    fontSize: wide ? 18 : 17,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                if (sessionLabel != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    sessionLabel!,
                    style: AppTextStyles.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ink.withValues(alpha: 0.85),
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A progress ring: finished / total sessions of a step, or today's goal.
class SessionRing extends StatelessWidget {
  const SessionRing({
    super.key,
    required this.size,
    required this.progress,
    required this.color,
    required this.track,
    this.stroke,
  });

  final double size;
  final double progress;
  final Color color;
  final Color track;
  final double? stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress.clamp(0.0, 1.0),
          color,
          track,
          stroke ?? math.max(4, size * 0.07),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track, this.stroke);

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base =
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final fill =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * progress, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
