import 'package:flutter/widgets.dart';

/// Moves [child] a little against the scroll, so a far layer seems to sit
/// behind the page. The child is laid out [overscan] taller on both ends
/// and only translated while scrolling: its picture is never repainted.
///
/// Outside a scrollable, or with [enabled] false, it is just the child.
class Parallax extends StatelessWidget {
  const Parallax({
    super.key,
    required this.child,
    required this.overscan,
    this.enabled = true,
  });

  final Widget child;
  final double overscan;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (!enabled || scrollable == null) {
      // Still: the same picture, centred in its overscan.
      return LayoutBuilder(
        builder:
            (context, constraints) => ClipRect(
              child: OverflowBox(
                minHeight: constraints.maxHeight + overscan * 2,
                maxHeight: constraints.maxHeight + overscan * 2,
                child: child,
              ),
            ),
      );
    }
    return Flow(
      delegate: _ParallaxDelegate(
        scrollable: scrollable,
        itemContext: context,
        overscan: overscan,
      ),
      children: [child],
    );
  }
}

class _ParallaxDelegate extends FlowDelegate {
  _ParallaxDelegate({
    required this.scrollable,
    required this.itemContext,
    required this.overscan,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext itemContext;
  final double overscan;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(
        Size(constraints.maxWidth, constraints.maxHeight + overscan * 2),
      );

  @override
  void paintChildren(FlowPaintingContext context) {
    var shift = 0.0;
    final viewport = scrollable.context.findRenderObject();
    final box = itemContext.findRenderObject();
    if (viewport is RenderBox &&
        box is RenderBox &&
        box.attached &&
        box.hasSize) {
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final vh = scrollable.position.viewportDimension;
      if (vh > 0) {
        final t = ((top + box.size.height / 2 - vh / 2) / vh).clamp(-1.0, 1.0);
        shift = -t * overscan;
      }
    }
    context.paintChild(
      0,
      transform: Matrix4.translationValues(0, -overscan + shift, 0),
    );
  }

  @override
  bool shouldRepaint(_ParallaxDelegate old) =>
      old.scrollable != scrollable ||
      old.itemContext != itemContext ||
      old.overscan != overscan;
}
