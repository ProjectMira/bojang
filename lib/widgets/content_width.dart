import 'package:flutter/widgets.dart';

/// Widths at which layouts change shape.
class Breakpoints {
  Breakpoints._();

  /// Narrowest width treated as a tablet (iPad in any orientation, or a
  /// large phone in landscape).
  static const double tablet = 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

/// Centers [child] and caps its width, so screens designed for a phone keep
/// comfortable line lengths and card sizes on an iPad instead of stretching
/// edge to edge. On a phone the cap is never reached and this does nothing.
///
/// Wrap a screen's body, not the whole Scaffold: the app bar and background
/// should still fill the screen.
class ContentWidth extends StatelessWidget {
  /// Default cap: about the width of an iPad mini in portrait.
  static const double standard = 720;

  /// Cap for focused, single-column tasks such as a quiz question.
  static const double reading = 640;

  final double maxWidth;
  final Widget child;

  const ContentWidth({
    super.key,
    this.maxWidth = standard,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
