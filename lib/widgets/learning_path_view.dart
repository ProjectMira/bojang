import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/learning_path.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tibetan_type.dart';
import 'app_text_style.dart';
import 'content_width.dart';
import 'scenery/biome.dart';
import 'scenery/clouds.dart';
export 'scenery/biome.dart' show Biome, BiomeX, biomeForUnit;
import 'scenery/landscape.dart';
import 'scenery/parallax.dart';
import 'scenery/signboard.dart';

/// The learning path as a journey through Tibet: each unit is a valley of
/// its own ([Biome]), with a sky and ranges, a signboard naming the unit,
/// and a trail across the valley floor through every step.
///
/// Rendering only: [onOpen] runs for a reachable step, [onLocked] for a
/// locked one (show why). The scenery spans the full width it is given;
/// the steps keep to a centred column at most [columnWidth] wide.
class LearningPathView extends StatefulWidget {
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

  /// The widest the column of steps and signboards gets (iPad).
  static const double columnWidth = 640;

  /// The landscape of [unit].
  static Biome biomeOf(PathUnit unit) => biomeForUnit(unit.index);

  /// The prayer-flag hue of [unit]'s open steps: its biome's hue.
  static AppHue hueOf(PathUnit unit) => biomeOf(unit).hue;

  @override
  State<LearningPathView> createState() => _LearningPathViewState();
}

class _LearningPathViewState extends State<LearningPathView>
    with SingleTickerProviderStateMixin {
  /// Drives drifting clouds and prayer flags; only at full motion.
  AnimationController? _ambient;
  MotionLevel _motion = MotionLevel.full;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = Motion.of(context);
    if (_motion.allowsLoops) {
      _ambient ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 90),
      )..repeat();
    } else {
      _ambient?.dispose();
      _ambient = null;
    }
  }

  @override
  void dispose() {
    _ambient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    final dark = AppTokens.isDark(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final unit in widget.path.units)
              _UnitScene(
                key: ValueKey('path_unit_${unit.id}'),
                unit: unit,
                width: width,
                tablet: tablet,
                dark: dark,
                ambient: _ambient,
                parallax: _motion.allowsLoops,
                activeKey: widget.activeKey,
                onTap:
                    (node) =>
                        node.isLocked
                            ? widget.onLocked(node)
                            : widget.onOpen(node),
              ),
          ],
        );
      },
    );
  }
}

/// One unit: the sky block (ranges, landmark, signboard) over the valley
/// floor with the trail and the steps.
class _UnitScene extends StatelessWidget {
  const _UnitScene({
    super.key,
    required this.unit,
    required this.width,
    required this.tablet,
    required this.dark,
    required this.ambient,
    required this.parallax,
    required this.activeKey,
    required this.onTap,
  });

  final PathUnit unit;
  final double width;
  final bool tablet;
  final bool dark;
  final Animation<double>? ambient;
  final bool parallax;
  final Key? activeKey;
  final void Function(PathNode node) onTap;

  static const double _overscan = 28;
  static const double _fade = 130;

  @override
  Widget build(BuildContext context) {
    final biome = LearningPathView.biomeOf(unit);
    final palette = BiomePalette.of(biome, dark: dark);
    final hue = biome.hue;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final nodeSize = tablet ? 92.0 : 72.0;
    final ring = nodeSize * 1.28;
    final swing = tablet ? 120.0 : 70.0;
    final trailWidth = tablet ? 30.0 : 24.0;
    final ridgeZone = tablet ? 230.0 : 190.0;
    final column = math.min(width, LearningPathView.columnWidth);
    final cx = width / 2;
    final slot = math.max(nodeSize * 2.6, 200.0);
    final labelH = 52 * textScale;

    // Lay the steps out on the valley floor.
    const top = 44.0;
    var y = top;
    final centers = <Offset>[];
    final clear = <Rect>[];
    final rows = <(PathNode, Offset, double)>[];
    for (var i = 0; i < unit.nodes.length; i++) {
      final node = unit.nodes[i];
      final x = cx + math.sin(i * math.pi / 3) * swing;
      final extra = node.isActive ? 64.0 : 0.0;
      centers.add(Offset(x, y + ring / 2));
      clear.add(
        Rect.fromLTWH(x - slot / 2, y - 6, slot, ring + 6 + labelH + extra),
      );
      rows.add((node, Offset(x - slot / 2, y), extra));
      y += ring + 6 + labelH + extra + 18;
    }
    final height = y + _fade;

    var walked = unit.nodes.length + 1;
    for (var i = 0; i < unit.nodes.length; i++) {
      final node = unit.nodes[i];
      if (node.isPassed) continue;
      walked = node.isLocked ? i : i + 1;
      break;
    }

    final layout = TrailLayout(
      centers: centers,
      keepClear: clear,
      walked: walked,
      trailWidth: trailWidth,
      columnLeft: (width - column) / 2,
      columnRight: (width + column) / 2,
      swing: swing,
      propScale: tablet ? 1.25 : 1.0,
    );

    final flags = switch (biome) {
      Biome.lake || Biome.pass || Biome.monastery || Biome.valley => true,
      _ => false,
    };

    final sky = Stack(
      children: [
        Positioned.fill(
          child: Parallax(
            enabled: parallax,
            overscan: _overscan,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: SkyPainter(
                  biome: biome,
                  palette: palette,
                  ridgeZone: ridgeZone,
                  seed: unit.index,
                  overscan: _overscan,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DriftingClouds(dark: dark, seed: unit.index, ambient: ambient),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: HorizonPainter(
                biome: biome,
                palette: palette,
                ridgeZone: ridgeZone,
                seed: unit.index,
                trailX: cx,
                trailWidth: trailWidth,
              ),
            ),
          ),
        ),
        if (flags)
          Positioned.fill(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, box) {
                  final h = box.maxHeight;
                  final w = box.maxWidth;
                  return CustomPaint(
                    painter: WindFlagsPainter(
                      palette: palette,
                      wind: ambient,
                      strings: [
                        (
                          Offset(w * 0.05, h - ridgeZone * 0.36),
                          Offset(w * 0.33, h - ridgeZone * 0.2),
                          14,
                        ),
                        (
                          Offset(w * 0.68, h - ridgeZone * 0.22),
                          Offset(w * 0.95, h - ridgeZone * 0.4),
                          12,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            tablet ? 56 : 40,
            AppSpacing.gutter,
            ridgeZone,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: PathUnitHeader(unit: unit, hue: hue),
            ),
          ),
        ),
      ],
    );

    final ground = SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: GroundPainter(
                  biome: biome,
                  palette: palette,
                  layout: layout,
                  seed: unit.index,
                  fade: _fade,
                ),
              ),
            ),
          ),
          for (final (node, at, _) in rows)
            Positioned(
              left: at.dx,
              top: at.dy,
              width: slot,
              child: PathNodeButton(
                key: node.isActive ? activeKey : null,
                node: node,
                hue: hue,
                size: nodeSize,
                onTap: () => onTap(node),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: biome.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ClipRect(child: sky), ground],
      ),
    );
  }
}

/// The unit's name on a signboard over its valley.
class PathUnitHeader extends StatelessWidget {
  const PathUnitHeader({super.key, required this.unit, required this.hue});

  final PathUnit unit;
  final AppHue hue;

  @override
  Widget build(BuildContext context) {
    final locked = unit.isLocked;
    final colors = SignboardColors.of(context);
    final lessons = unit.nodes.length;
    final done = unit.passedCount;
    return Semantics(
      header: true,
      label:
          'Unit ${unit.index}, ${unit.title}. $done of $lessons steps done'
          '${locked ? ', locked' : ''}',
      excludeSemantics: true,
      child: Signboard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit ${unit.index}',
                    style: AppTextStyles.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.inkSoft,
                    ),
                  ),
                  Text(
                    unit.title,
                    style: AppTextStyles.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: colors.ink,
                    ),
                  ),
                  if (unit.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      unit.description,
                      style: AppTextStyles.poppins(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked)
                  Icon(Icons.lock_rounded, size: 18, color: colors.inkSoft)
                else
                  Text(
                    '$done/$lessons',
                    style: AppTextStyles.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
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
        // A plain stone set in the trail.
        face = dark ? const Color(0xFF3A4352) : const Color(0xFFD9DDE3);
        lip = dark ? const Color(0xFF232A35) : const Color(0xFFA9B0BA);
        ink = dark ? const Color(0xFFAFB8C7) : const Color(0xFF5E6A78);
      case PathNodeState.active:
      case PathNodeState.unlocked:
        face = dark ? hue.night : hue.face;
        lip = dark ? hue.nightTint : hue.lip;
        ink = dark ? AppColors.inkLight : hue.onFace;
    }
    // The rim that lifts every step off the painted ground.
    final rim = dark ? const Color(0xFF0F1626) : const Color(0xFFFFFFFF);

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
      scale: _pressed ? 0.96 : 1,
      duration: Motion.of(context).scale(const Duration(milliseconds: 120)),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: face,
          shape: BoxShape.circle,
          border: Border.all(color: rim, width: 3),
          boxShadow: [
            BoxShadow(color: lip, offset: Offset(0, size * 0.08)),
            BoxShadow(
              color: const Color(
                0xFF000000,
              ).withValues(alpha: dark ? 0.45 : 0.22),
              offset: Offset(0, size * 0.12),
              blurRadius: 8,
            ),
          ],
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
              track: rim.withValues(alpha: dark ? 0.55 : 0.7),
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
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: size * 2.4),
            child: _LabelPlate(
              text: node.title,
              strong: node.isActive,
              locked: node.isLocked,
              fontSize: size > 80 ? 14 : 13,
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

/// The step's name on a small plaster plate, readable over any ground.
class _LabelPlate extends StatelessWidget {
  const _LabelPlate({
    required this.text,
    required this.strong,
    required this.locked,
    required this.fontSize,
  });

  final String text;
  final bool strong;
  final bool locked;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = SignboardColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.poppins(
            fontSize: fontSize,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
            color: locked ? colors.inkSoft : colors.ink,
          ),
        ),
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
    // The lip sits under the face: drawn outside the Material so it never
    // covers the fill.
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [
            BoxShadow(
              color: dark ? hue.nightTint : hue.lip,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
