import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../models/experiment_exposure.dart';
import 'analytics.dart';
import 'event_tracker.dart';
import 'remote_settings.dart';

/// Experiment arms and exposure logging (plan item #21).
///
/// The rule: **assignment is not exposure.** Reading which arm a learner is
/// in ([arm], [posthogArm] without `exposed`) logs nothing. Call [exposed]
/// (or wrap the widget in [ExperimentExposure]) only where the UI actually
/// shows that arm to the learner. `experiment_exposed {experiment, arm,
/// surface, source}` then goes out once per experiment and arm per app
/// session. Analyse experiments on exposed learners only. See
/// ANALYTICS_EVENTS.md.
///
/// Arms come from Remote Config `exp_*` parameters (assigned with a "user in
/// random percentile" condition) or PostHog multivariate flags.
class Experiments {
  Experiments._();

  static final ExposureLog _log = ExposureLog();

  /// Replaced in tests.
  @visibleForTesting
  static void Function(String event, Map<String, Object?> properties) send =
      Analytics.track;

  /// Replaced in tests.
  @visibleForTesting
  static String Function() sessionId = () => EventTracker.instance.sessionId;

  /// The learner's arm of a Remote Config experiment (`exp_*` parameter),
  /// or [fallback] when it has no value. Logs nothing.
  static String arm(String experiment, {String fallback = 'control'}) {
    final value = RemoteSettings.getString(experiment).trim();
    return value.isEmpty ? fallback : value;
  }

  /// [arm] plus [exposed], for code that reads the arm right where it is
  /// shown (inside `build`). Prefer [ExperimentExposure] for widgets.
  static String show(
    String experiment, {
    String fallback = 'control',
    String? surface,
  }) {
    final value = arm(experiment, fallback: fallback);
    exposed(experiment, value, surface: surface);
    return value;
  }

  /// Records that the UI showed [arm] of [experiment]. Only the first call
  /// per experiment and arm in an app session sends `experiment_exposed`.
  static void exposed(
    String experiment,
    String arm, {
    String? surface,
    String source = 'remote_config',
  }) {
    if (experiment.isEmpty) return;
    if (!_log.firstExposure(sessionId(), experiment, arm)) return;
    send('experiment_exposed', {
      'experiment': experiment,
      'arm': arm,
      'surface': surface,
      'source': source,
    });
  }

  /// The learner's arm of a PostHog feature flag ([fallback] when the flag
  /// is off or unknown). With [exposed] false nothing is logged anywhere
  /// (PostHog's own `$feature_flag_called` is suppressed too); pass true
  /// only where the arm is on screen, which logs both.
  static Future<String> posthogArm(
    String flag, {
    String fallback = 'control',
    bool exposed = false,
    String? surface,
  }) async {
    Object? value;
    if (Analytics.enabled) {
      try {
        value = await Posthog().getFeatureFlag(
          flag,
          sendFeatureFlagEvent: exposed,
        );
      } catch (e) {
        debugPrint('PostHog flag $flag unavailable: $e');
      }
    }
    final result =
        value is String && value.isNotEmpty
            ? value
            : (value == true ? 'test' : fallback);
    if (exposed) {
      Experiments.exposed(flag, result, surface: surface, source: 'posthog');
    }
    return result;
  }

  @visibleForTesting
  static void debugReset() => _log.clear();
}

/// Logs exposure of [arm] when this widget is first built, and again if the
/// arm changes: put it around the part of the screen that differs between
/// arms, so exposure means "was on screen".
///
/// ```dart
/// final arm = Experiments.arm('exp_home_cta');
/// ExperimentExposure(
///   experiment: 'exp_home_cta',
///   arm: arm,
///   surface: 'home',
///   child: arm == 'short' ? const Text('Start') : const Text('Start a lesson'),
/// )
/// ```
class ExperimentExposure extends StatefulWidget {
  const ExperimentExposure({
    super.key,
    required this.experiment,
    required this.arm,
    required this.child,
    this.surface,
    this.source = 'remote_config',
  });

  final String experiment;
  final String arm;
  final String? surface;
  final String source;
  final Widget child;

  @override
  State<ExperimentExposure> createState() => _ExperimentExposureState();
}

class _ExperimentExposureState extends State<ExperimentExposure> {
  @override
  void initState() {
    super.initState();
    _log();
  }

  @override
  void didUpdateWidget(ExperimentExposure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.arm != widget.arm ||
        oldWidget.experiment != widget.experiment) {
      _log();
    }
  }

  void _log() => Experiments.exposed(
    widget.experiment,
    widget.arm,
    surface: widget.surface,
    source: widget.source,
  );

  @override
  Widget build(BuildContext context) => widget.child;
}
