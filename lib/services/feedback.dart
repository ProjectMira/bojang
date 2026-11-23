/// One event, three senses, one name (plan item #13).
///
/// `Feedback.play(FeedbackEvent.correct, context: context)` fires the yak's
/// reaction, the sound and the haptic together, so every screen feels the
/// same and a change to "what a right answer feels like" happens here once.
///
/// | Event                   | Sound                                  | Haptic                         | Yak                          |
/// |-------------------------|----------------------------------------|--------------------------------|------------------------------|
/// | `correct`               | `correct.mp3`, rising `correct_1..4`   | light                          | `correct_trig` (hop)         |
/// | `incorrect`             | `incorrect.mp3`, quieter               | medium                         | `incorrect_trig` (shake)     |
/// | `correct_after_mistake` | `correct_after_mistake.mp3`            | light, medium                  | `correct_after_mistake_trig` |
/// | `lesson_complete`       | `lesson_complete.mp3`                  | medium, light, heavy           | `reset_trig`                 |
/// | `streak_extended`       | `streak_extended.mp3`                  | light, light, medium           | none                         |
/// | `tier_up`               | `tier_up.mp3`                          | light, medium, heavy, heavy    | none                         |
/// | `tap`                   | `tap.mp3`                              | light                          | none                         |
/// | `select`                | `select.mp3`                           | selection click                | none                         |
///
/// Settings: "Sound effects" (ThemeService) and "Haptics" ([haptics]) are
/// separate switches. Under reduced or static motion (Settings > Animations
/// or the system's Reduce Motion) haptic sequences collapse to their first
/// pulse and the yak plays its reduced reaction or none.
///
/// Material also exports a `Feedback` class, so files that call this one
/// import material with `hide Feedback`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/motion.dart';
import '../widgets/yak_controller.dart';
import 'analytics.dart';
import 'sound_effects.dart';
import 'theme_service.dart';

enum FeedbackEvent {
  correct('correct'),
  incorrect('incorrect'),
  correctAfterMistake('correct_after_mistake'),
  lessonComplete('lesson_complete'),
  streakExtended('streak_extended'),
  tierUp('tier_up'),
  tap('tap'),
  select('select');

  const FeedbackEvent(this.id);

  /// The shared name: sound file stem, haptic name and analytics value.
  final String id;
}

enum HapticKind { light, medium, heavy, selection }

/// One pulse of a haptic pattern, [after] the previous one.
@immutable
class HapticStep {
  const HapticStep(this.kind, {this.after = Duration.zero});

  final HapticKind kind;
  final Duration after;

  @override
  bool operator ==(Object other) =>
      other is HapticStep && other.kind == kind && other.after == after;

  @override
  int get hashCode => Object.hash(kind, after);

  @override
  String toString() => 'HapticStep($kind, +${after.inMilliseconds}ms)';
}

/// What one event does to each sense.
@immutable
class FeedbackCue {
  const FeedbackCue({
    required this.sound,
    required this.haptic,
    this.volume = 1,
    this.yak,
    this.ui = false,
  });

  /// Asset path under `assets/`, for example `audio/correct.mp3`.
  final String? sound;

  /// Multiplies the Settings volume. Wrong answers are quieter on purpose.
  final double volume;
  final List<HapticStep> haptic;
  final YakTrigger? yak;

  /// Taps and selections play on their own channel so they never cut off
  /// an answer chime.
  final bool ui;
}

/// The escalation state for one lesson or game round: consecutive right
/// answers raise the correct chime a step (up to [Feedback.correctSteps]),
/// a mistake resets it.
class FeedbackSession {
  int _run = 0;
  bool _lastWasMistake = false;

  /// Right answers in a row, the one just played included.
  int get run => _run;
  bool get lastWasMistake => _lastWasMistake;

  /// The event for an answer: a right answer straight after a miss is the
  /// recovery reaction, not a plain correct.
  FeedbackEvent resolve(bool correct) {
    if (!correct) return FeedbackEvent.incorrect;
    return _lastWasMistake
        ? FeedbackEvent.correctAfterMistake
        : FeedbackEvent.correct;
  }

  /// Records [event] and returns the correct-chime step it plays (0 when it
  /// is not a correct answer).
  int record(FeedbackEvent event) {
    switch (event) {
      case FeedbackEvent.correct:
        _run++;
        _lastWasMistake = false;
        return (_run - 1).clamp(0, Feedback.correctSteps - 1);
      case FeedbackEvent.correctAfterMistake:
        _run = 1;
        _lastWasMistake = false;
        return 0;
      case FeedbackEvent.incorrect:
        _run = 0;
        _lastWasMistake = true;
        return 0;
      case FeedbackEvent.lessonComplete:
        reset();
        return 0;
      case FeedbackEvent.streakExtended:
      case FeedbackEvent.tierUp:
      case FeedbackEvent.tap:
      case FeedbackEvent.select:
        return 0;
    }
  }

  void reset() {
    _run = 0;
    _lastWasMistake = false;
  }
}

/// Settings > Audio > Haptics, saved on the device. On by default.
class HapticsSetting extends ValueNotifier<bool> {
  HapticsSetting() : super(true);

  static const String prefsKey = 'haptics_enabled';

  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(prefsKey) ?? true;
    } catch (_) {
      // Keep the default.
    }
  }

  Future<void> set(bool on) async {
    await load();
    value = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, on);
    Analytics.track('setting_changed', {'setting': 'haptics', 'value': on});
    Analytics.setPersonProperties({'haptics': on});
  }

  @visibleForTesting
  void resetForTest() {
    _loading = null;
    value = true;
  }
}

/// What the device does with a cue. Swapped for a recorder in tests.
abstract class FeedbackOutputs {
  Future<void> sound(String asset, {required double volume, required bool ui});
  Future<void> haptic(HapticKind kind);
  Future<void> wait(Duration duration);
}

class DeviceFeedbackOutputs implements FeedbackOutputs {
  const DeviceFeedbackOutputs();

  @override
  Future<void> sound(
    String asset, {
    required double volume,
    required bool ui,
  }) => SoundEffects.instance.playAsset(asset, volume: volume, ui: ui);

  @override
  Future<void> haptic(HapticKind kind) => switch (kind) {
    HapticKind.light => HapticFeedback.lightImpact(),
    HapticKind.medium => HapticFeedback.mediumImpact(),
    HapticKind.heavy => HapticFeedback.heavyImpact(),
    HapticKind.selection => HapticFeedback.selectionClick(),
  };

  @override
  Future<void> wait(Duration duration) => Future.delayed(duration);
}

/// The Settings and motion state one play reads.
@immutable
class FeedbackEnv {
  const FeedbackEnv({
    required this.soundOn,
    this.volume = 1,
    required this.hapticsOn,
    this.motion = MotionLevel.full,
  });

  final bool soundOn;
  final double volume;
  final bool hapticsOn;
  final MotionLevel motion;
}

class Feedback {
  Feedback._();

  /// Pitch steps of the correct chime: `correct.mp3` then `correct_1..4`.
  static const int correctSteps = 5;

  static String correctSound(int step) {
    final s = step.clamp(0, correctSteps - 1);
    return s == 0 ? 'audio/correct.mp3' : 'audio/correct_$s.mp3';
  }

  static const Duration _beat = Duration(milliseconds: 90);

  /// The event → senses table. [correctStep] only matters for `correct`.
  static FeedbackCue cueFor(FeedbackEvent event, {int correctStep = 0}) {
    const l = HapticKind.light;
    const m = HapticKind.medium;
    const h = HapticKind.heavy;
    return switch (event) {
      FeedbackEvent.correct => FeedbackCue(
        sound: correctSound(correctStep),
        haptic: const [HapticStep(l)],
        yak: YakTrigger.correct,
      ),
      FeedbackEvent.incorrect => const FeedbackCue(
        sound: 'audio/incorrect.mp3',
        volume: 0.6,
        haptic: [HapticStep(m)],
        yak: YakTrigger.incorrect,
      ),
      FeedbackEvent.correctAfterMistake => const FeedbackCue(
        sound: 'audio/correct_after_mistake.mp3',
        haptic: [HapticStep(l), HapticStep(m, after: _beat)],
        yak: YakTrigger.correctAfterMistake,
      ),
      FeedbackEvent.lessonComplete => const FeedbackCue(
        sound: 'audio/lesson_complete.mp3',
        haptic: [
          HapticStep(m),
          HapticStep(l, after: Duration(milliseconds: 110)),
          HapticStep(h, after: Duration(milliseconds: 110)),
        ],
        yak: YakTrigger.reset,
      ),
      FeedbackEvent.streakExtended => const FeedbackCue(
        sound: 'audio/streak_extended.mp3',
        haptic: [
          HapticStep(l),
          HapticStep(l, after: Duration(milliseconds: 70)),
          HapticStep(m, after: Duration(milliseconds: 70)),
        ],
      ),
      FeedbackEvent.tierUp => const FeedbackCue(
        sound: 'audio/tier_up.mp3',
        haptic: [
          HapticStep(l),
          HapticStep(m, after: Duration(milliseconds: 80)),
          HapticStep(h, after: Duration(milliseconds: 80)),
          HapticStep(h, after: Duration(milliseconds: 220)),
        ],
      ),
      FeedbackEvent.tap => const FeedbackCue(
        sound: 'audio/tap.mp3',
        volume: 0.7,
        haptic: [HapticStep(l)],
        ui: true,
      ),
      FeedbackEvent.select => const FeedbackCue(
        sound: 'audio/select.mp3',
        volume: 0.8,
        haptic: [HapticStep(HapticKind.selection)],
        ui: true,
      ),
    };
  }

  static final FeedbackSession session = FeedbackSession();

  /// The lesson yak: the quiz answer banner listens to it.
  static final YakController yak = YakController();

  static final HapticsSetting haptics = HapticsSetting();

  static FeedbackOutputs outputs = const DeviceFeedbackOutputs();

  static ThemeService? _lastTheme;

  /// Starts a lesson or game round: the correct chime goes back to step 0.
  static void startLesson() => session.reset();

  /// Plays a right or wrong answer, picking `correct_after_mistake` for a
  /// right answer straight after a miss.
  static Future<void> answer(bool correct, {BuildContext? context}) =>
      play(session.resolve(correct), context: context);

  /// Fires [event] on every sense the learner has switched on.
  static Future<void> play(FeedbackEvent event, {BuildContext? context}) async {
    final env = _envOf(context);
    await haptics.load();
    return playWith(
      event,
      FeedbackEnv(
        soundOn: env.soundOn,
        volume: env.volume,
        hapticsOn: haptics.value,
        motion: env.motion,
      ),
    );
  }

  /// [play] with the environment spelled out (tests, previews).
  static Future<void> playWith(FeedbackEvent event, FeedbackEnv env) async {
    final step = session.record(event);
    final cue = cueFor(event, correctStep: step);
    if (cue.yak != null) yak.fire(cue.yak!);
    final jobs = <Future<void>>[];
    if (env.soundOn && cue.sound != null && env.volume > 0) {
      jobs.add(
        outputs.sound(cue.sound!, volume: env.volume * cue.volume, ui: cue.ui),
      );
    }
    if (env.hapticsOn) {
      jobs.add(_runHaptics(hapticsFor(cue, env.motion)));
    }
    await Future.wait(jobs);
  }

  /// Sequences collapse to their first pulse unless motion is full.
  static List<HapticStep> hapticsFor(FeedbackCue cue, MotionLevel motion) =>
      motion == MotionLevel.full || cue.haptic.isEmpty
          ? cue.haptic
          : [HapticStep(cue.haptic.first.kind)];

  static Future<void> _runHaptics(List<HapticStep> steps) async {
    for (final step in steps) {
      if (step.after > Duration.zero) await outputs.wait(step.after);
      try {
        await outputs.haptic(step.kind);
      } catch (_) {
        // A device without a vibrator is not an error.
      }
    }
  }

  static FeedbackEnv _envOf(BuildContext? context) {
    ThemeService? theme;
    var motion = MotionLevel.full;
    if (context != null && context.mounted) {
      try {
        theme = Provider.of<ThemeService>(context, listen: false);
      } on ProviderNotFoundException {
        theme = null;
      }
      motion = Motion.read(context);
    }
    theme ??= _lastTheme;
    _lastTheme = theme;
    return FeedbackEnv(
      soundOn: theme?.soundEffectsEnabled ?? false,
      volume: theme?.soundEffectsVolume ?? 1,
      hapticsOn: true,
      motion: motion,
    );
  }
}
