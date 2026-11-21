import 'package:flutter/material.dart';

import '../utils/streak_calendar.dart';

/// Colors shared by the streak week row and the streak calendar.
class StreakColors {
  StreakColors._();

  static const fire = Color(0xFFFF9600);
  static const fireDeep = Color(0xFFFF5722);
}

/// One day as a circle: a flame if practiced, an orange ring for today while
/// it's still open, and plain otherwise. Missed days are deliberately plain,
/// not marked as failures. [label] (usually the day number) is shown inside
/// every day that isn't practiced.
class StreakDayBubble extends StatelessWidget {
  const StreakDayBubble({
    super.key,
    required this.state,
    required this.size,
    this.isToday = false,
    this.label,
  });

  final StreakDayState state;
  final double size;
  final bool isToday;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plainFill = isDark ? Colors.white10 : Colors.grey.shade100;
    // Past days read a little stronger than days still to come.
    final pastText = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final plainText = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    BoxDecoration decoration;
    Widget? child;
    switch (state) {
      case StreakDayState.practiced:
        decoration = const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [StreakColors.fire, StreakColors.fireDeep],
          ),
        );
        child = Text('🔥', style: TextStyle(fontSize: size * 0.46, height: 1));
      case StreakDayState.missed:
      case StreakDayState.open:
      case StreakDayState.future:
      case StreakDayState.beforeStart:
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          // With a day number inside, the number alone is enough; an
          // unlabelled circle (the week row) needs a fill to be seen.
          color:
              state == StreakDayState.open || label != null ? null : plainFill,
        );
        child =
            label == null
                ? null
                : Text(
                  label!,
                  style: TextStyle(
                    fontSize: size * 0.36,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color:
                        isToday
                            ? StreakColors.fire
                            : state == StreakDayState.missed
                            ? pastText
                            : plainText,
                  ),
                );
    }

    if (isToday && state != StreakDayState.practiced) {
      decoration = decoration.copyWith(
        border: Border.all(color: StreakColors.fire, width: 2),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: decoration,
      child: child,
    );
  }
}
