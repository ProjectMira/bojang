import 'package:flutter/widgets.dart';

import 'biome.dart';
import 'landscape.dart';

/// Painterly clouds in the sky. At full motion they drift (a translation of a
/// cached picture); otherwise they hold still.
class DriftingClouds extends StatelessWidget {
  const DriftingClouds({
    super.key,
    required this.palette,
    required this.seed,
    this.ambient,
    this.top = 0.18,
    this.bottom = 0.42,
  });

  /// The band of the height the clouds float in.
  final double top;
  final double bottom;

  final BiomePalette palette;
  final int seed;
  final Animation<double>? ambient;

  @override
  Widget build(BuildContext context) {
    final picture = RepaintBoundary(
      child: CustomPaint(
        painter: CloudPainter(
          palette: palette,
          seed: seed,
          top: top,
          bottom: bottom,
        ),
      ),
    );
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final tiled = OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: w * 2,
            maxWidth: w * 2,
            child: picture,
          );
          final a = ambient;
          if (a == null) {
            return Transform.translate(
              offset: Offset(-w * 0.3, 0),
              child: tiled,
            );
          }
          return AnimatedBuilder(
            animation: a,
            builder:
                (context, child) => Transform.translate(
                  offset: Offset(-w * ((a.value + seed * 0.17) % 1.0), 0),
                  child: child,
                ),
            child: tiled,
          );
        },
      ),
    );
  }
}
