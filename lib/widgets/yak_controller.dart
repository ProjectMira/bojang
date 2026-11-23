/// The yak's state-machine contract (plan item #14), shared by every way of
/// drawing Norbu: today the code-drawn [YakMascot], later a Rive file.
///
/// The names below are the contract with the animator. They match the
/// inputs of the `yak_sm` state machine in `assets/rive/yak.riv` one for
/// one, so swapping renderers never changes a call site. The full brief is
/// `docs/YAK_ANIMATION_CONTRACT.md`; change both together.
///
/// | Input                         | Type    | Meaning                         |
/// |-------------------------------|---------|---------------------------------|
/// | `correct_trig`                | trigger | right answer: a hop             |
/// | `incorrect_trig`              | trigger | wrong answer: a head shake      |
/// | `correct_after_mistake_trig`  | trigger | right after a miss: a cheer     |
/// | `reset_trig`                  | trigger | drop any reaction, back to idle |
/// | `idle_num`                    | number  | idle variant, 0..[idleVariants]-1 |
/// | `dark_mode_bool`              | boolean | the app is in dark mode         |
/// | `reduced_motion_bool`         | boolean | MotionLevel is reduced/static   |
library;

import 'package:flutter/foundation.dart';

import '../theme/motion.dart';

/// The one-shot inputs, each named exactly as in `yak_sm`.
enum YakTrigger {
  correct('correct_trig'),
  incorrect('incorrect_trig'),
  correctAfterMistake('correct_after_mistake_trig'),
  reset('reset_trig');

  const YakTrigger(this.input);

  /// The Rive input name.
  final String input;

  static YakTrigger? fromInput(String name) {
    for (final t in values) {
      if (t.input == name) return t;
    }
    return null;
  }
}

/// Where the state machine is. Every reaction is one-shot and falls back to
/// [idle] on its own.
enum YakState {
  idle,
  correct,
  incorrect,
  correctAfterMistake;

  /// How long the reaction plays at full motion. The animator's budget: a
  /// reaction has to finish well inside the 2 s answer banner.
  Duration get duration => switch (this) {
    YakState.idle => Duration.zero,
    YakState.correct => const Duration(milliseconds: 460),
    YakState.incorrect => const Duration(milliseconds: 520),
    YakState.correctAfterMistake => const Duration(milliseconds: 820),
  };
}

/// Drives one yak. Fire triggers from anywhere ([fire] / [fireInput]); the
/// renderer listens, plays the reaction for [reaction] and calls
/// [finishReaction] when it ends.
///
/// Environment inputs ([darkMode], [reducedMotion]) are pushed by the
/// renderer from its `BuildContext` through [syncEnvironment], which does
/// not notify: the renderer already rebuilds when the theme or motion level
/// changes.
class YakController extends ChangeNotifier {
  YakController({int idleNum = 0}) : _idleNum = _clampIdle(idleNum);

  /// State machine name inside the Rive file.
  static const String stateMachine = 'yak_sm';

  /// Where the Rive file will live once an animator delivers it.
  static const String riveAsset = 'assets/rive/yak.riv';

  static const String idleNumInput = 'idle_num';
  static const String darkModeInput = 'dark_mode_bool';
  static const String reducedMotionInput = 'reduced_motion_bool';

  /// Idle variants the code-drawn yak has: 0 calm breathing and blinking,
  /// 1 looking around, 2 slow and sleepy. A Rive file may ship more; the
  /// contract only promises 0 exists.
  static const int idleVariants = 3;

  /// Every input in `yak_sm`, for checking a delivered file.
  static List<String> get inputNames => [
    for (final t in YakTrigger.values) t.input,
    idleNumInput,
    darkModeInput,
    reducedMotionInput,
  ];

  YakState _state = YakState.idle;
  int _reaction = 0;
  int _idleNum;
  bool _darkMode = false;
  bool _reducedMotion = false;
  YakTrigger? _lastTrigger;

  YakState get state => _state;

  /// Goes up by one on every trigger, so a renderer can tell "correct
  /// again" from "still the same correct".
  int get reaction => _reaction;

  YakTrigger? get lastTrigger => _lastTrigger;
  int get idleNum => _idleNum;
  bool get darkMode => _darkMode;
  bool get reducedMotion => _reducedMotion;

  static int _clampIdle(int v) => v.clamp(0, idleVariants - 1);

  /// The state a trigger moves to. A trigger always wins over a reaction
  /// still playing: the newest answer is the one the yak reacts to.
  static YakState stateAfter(YakTrigger trigger) => switch (trigger) {
    YakTrigger.correct => YakState.correct,
    YakTrigger.incorrect => YakState.incorrect,
    YakTrigger.correctAfterMistake => YakState.correctAfterMistake,
    YakTrigger.reset => YakState.idle,
  };

  void fire(YakTrigger trigger) {
    _state = stateAfter(trigger);
    _lastTrigger = trigger;
    _reaction++;
    notifyListeners();
  }

  /// Fires by Rive input name. Returns false for a name not in the
  /// contract (nothing changes).
  bool fireInput(String name) {
    final trigger = YakTrigger.fromInput(name);
    if (trigger == null) return false;
    fire(trigger);
    return true;
  }

  /// The renderer finished reaction number [serial]. A stale serial (a newer
  /// trigger already took over) is ignored.
  void finishReaction(int serial) {
    if (serial != _reaction || _state == YakState.idle) return;
    _state = YakState.idle;
    notifyListeners();
  }

  set idleNum(int value) {
    final v = _clampIdle(value);
    if (v == _idleNum) return;
    _idleNum = v;
    notifyListeners();
  }

  /// Pushes `dark_mode_bool` and `reduced_motion_bool` from the renderer's
  /// context. Silent on purpose; returns whether anything changed.
  bool syncEnvironment({required bool darkMode, required MotionLevel motion}) {
    final reduced = motion != MotionLevel.full;
    final changed = darkMode != _darkMode || reduced != _reducedMotion;
    _darkMode = darkMode;
    _reducedMotion = reduced;
    return changed;
  }

  /// How long the current kind of reaction lasts at [motion]: the full
  /// length, half under reduced motion, nothing when static.
  static Duration reactionLength(YakState state, MotionLevel motion) =>
      motion.scale(state.duration);
}
