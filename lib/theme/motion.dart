/// How much the app animates: one level every animation reads.
///
/// It combines three signals and takes the most restrictive:
///
/// * the system setting (`MediaQuery.disableAnimations`: iOS Reduce Motion,
///   Android "Remove animations"),
/// * the learner's own Settings > Animations choice,
/// * a low-RAM device check, so older Android phones skip the idle loops
///   and confetti that make them stutter.
library;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';

enum MotionLevel {
  /// Everything: idle loops, confetti, springs.
  full,

  /// State changes still animate, briefly. No idle loops or confetti.
  reduced,

  /// Nothing moves on its own; changes cut straight to the end state.
  static,
}

/// The learner's choice in Settings > Animations.
enum AnimationPreference {
  full,
  reduced,
  off;

  static AnimationPreference fromId(String? id) => AnimationPreference.values
      .firstWhere((p) => p.name == id, orElse: () => AnimationPreference.full);

  String get title => switch (this) {
    AnimationPreference.full => 'Full',
    AnimationPreference.reduced => 'Reduced',
    AnimationPreference.off => 'Off',
  };

  String get subtitle => switch (this) {
    AnimationPreference.full => 'Celebrations, confetti and a lively yak',
    AnimationPreference.reduced => 'Short transitions only, nothing looping',
    AnimationPreference.off => 'No animation',
  };
}

extension MotionLevelX on MotionLevel {
  /// Ambient or looping motion: the yak's idle loop, confetti bursts.
  bool get allowsLoops => this == MotionLevel.full;

  /// Celebration choreography (confetti, pops) at lesson and streak ends.
  bool get allowsCelebration => this == MotionLevel.full;

  /// Any animation at all, including short transitions.
  bool get animates => this != MotionLevel.static;

  /// [full] at full motion, about half under reduced, zero when static.
  Duration scale(Duration full) => switch (this) {
    MotionLevel.full => full,
    MotionLevel.reduced => full * 0.5,
    MotionLevel.static => Duration.zero,
  };
}

class Motion {
  Motion._();

  /// Phones below this much RAM (in MB, as the OS reports it) get reduced
  /// motion by default. A phone sold as "4 GB" reports about 3.6 GB, so
  /// this catches 2 and 3 GB phones without touching 4 GB ones.
  static const int lowRamThresholdMb = 3072;

  /// Whether a device counts as low-RAM. [physicalRamMb] is null or 0 when
  /// the platform did not report it.
  static bool isLowRam({int? physicalRamMb, bool osLowRamFlag = false}) {
    if (osLowRamFlag) return true;
    if (physicalRamMb == null || physicalRamMb <= 0) return false;
    return physicalRamMb < lowRamThresholdMb;
  }

  /// The most restrictive of the three signals. The learner can always ask
  /// for less motion, never for more than the system allows.
  static MotionLevel resolve({
    AnimationPreference preference = AnimationPreference.full,
    bool systemDisableAnimations = false,
    bool lowRamDevice = false,
  }) {
    if (systemDisableAnimations || preference == AnimationPreference.off) {
      return MotionLevel.static;
    }
    if (preference == AnimationPreference.reduced || lowRamDevice) {
      return MotionLevel.reduced;
    }
    return MotionLevel.full;
  }

  /// The level for [context], rebuilding when the system setting or the
  /// learner's choice changes. Use in `build` or `didChangeDependencies`.
  static MotionLevel of(BuildContext context) {
    final theme = _theme(context, listen: true);
    return resolve(
      preference: theme?.animationPreference ?? AnimationPreference.full,
      systemDisableAnimations:
          MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      lowRamDevice: theme?.isLowRamDevice ?? false,
    );
  }

  /// Like [of] without subscribing, so it is safe in `initState`.
  static MotionLevel read(BuildContext context) {
    final theme = _theme(context, listen: false);
    final system =
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    return resolve(
      preference: theme?.animationPreference ?? AnimationPreference.full,
      systemDisableAnimations: system,
      lowRamDevice: theme?.isLowRamDevice ?? false,
    );
  }

  static ThemeService? _theme(BuildContext context, {required bool listen}) {
    try {
      return Provider.of<ThemeService>(context, listen: listen);
    } on ProviderNotFoundException {
      // Widget tests and previews that build a widget on its own.
      return null;
    }
  }
}

/// [AnimatedSize] that becomes a plain child when [duration] is zero
/// (Animations off or Reduce Motion). A zero-length AnimatedSize finishes
/// inside its own layout and trips "RenderAnimatedSize was mutated in its
/// own performLayout".
class MotionAnimatedSize extends StatelessWidget {
  const MotionAnimatedSize({
    super.key,
    required this.duration,
    required this.child,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
  });

  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: alignment,
      child: child,
    );
  }
}
