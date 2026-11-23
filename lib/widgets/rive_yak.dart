/// The Rive yak: a stub behind a flag until an animator delivers
/// `assets/rive/yak.riv` (plan item #14, `docs/YAK_ANIMATION_CONTRACT.md`).
///
/// What is here and works today is [RiveYakBinding]: it maps a
/// [YakController] onto the `yak_sm` inputs through a small [YakInputSink].
/// The renderer only has to supply a sink over the Rive runtime's state
/// machine, so the day the file lands the change is one adapter:
///
/// ```dart
/// // with package:rive added
/// class _RiveSink implements YakInputSink {
///   _RiveSink(this.sm);
///   final StateMachine sm;
///   void fireTrigger(String name) => sm.trigger(name)?.fire();
///   void setNumber(String name, double v) => sm.number(name)?.value = v;
///   void setBool(String name, bool v) => sm.boolean(name)?.value = v;
/// }
/// ```
///
/// The `rive` package is NOT a dependency yet (it adds native libraries for
/// every ABI, for a file that does not exist). Until it is, [RiveYak.enabled]
/// is false whatever the flag says, and [YakMascot] keeps drawing the yak in
/// code from the same controller.
library;

import 'package:flutter/widgets.dart';

import 'yak_controller.dart';

/// `--dart-define=RIVE_YAK=true` asks for the Rive yak.
const bool kRiveYakFlag = bool.fromEnvironment('RIVE_YAK');

/// Where a renderer receives the contract's inputs. Names are the `yak_sm`
/// input names from [YakController].
abstract class YakInputSink {
  void fireTrigger(String name);
  void setNumber(String name, double value);
  void setBool(String name, bool value);
}

/// Keeps a [YakInputSink] in step with a [YakController]: fires each new
/// trigger once, mirrors `idle_num`, and pushes the two environment
/// booleans when they change.
class RiveYakBinding {
  RiveYakBinding(this.controller, this.sink);

  /// The optional Rive event the file fires when a one-shot reaction ends.
  /// Without it the binding still works; the controller just learns of the
  /// end from [YakState.duration] instead.
  static const String reactionDoneEvent = 'reaction_done_event';

  final YakController controller;
  final YakInputSink sink;

  int _seenReaction = 0;
  int? _sentIdle;
  bool? _sentDark;
  bool? _sentReduced;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    _seenReaction = controller.reaction;
    syncInputs();
    controller.addListener(_onChange);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    controller.removeListener(_onChange);
  }

  /// Pushes `idle_num`, `dark_mode_bool` and `reduced_motion_bool` if they
  /// changed since the last push. Call after [YakController.syncEnvironment].
  void syncInputs() {
    if (_sentIdle != controller.idleNum) {
      _sentIdle = controller.idleNum;
      sink.setNumber(YakController.idleNumInput, controller.idleNum.toDouble());
    }
    if (_sentDark != controller.darkMode) {
      _sentDark = controller.darkMode;
      sink.setBool(YakController.darkModeInput, controller.darkMode);
    }
    if (_sentReduced != controller.reducedMotion) {
      _sentReduced = controller.reducedMotion;
      sink.setBool(YakController.reducedMotionInput, controller.reducedMotion);
    }
  }

  /// Forward a Rive event from the file.
  void onRiveEvent(String name) {
    if (name == reactionDoneEvent) {
      controller.finishReaction(controller.reaction);
    }
  }

  void _onChange() {
    syncInputs();
    if (controller.reaction == _seenReaction) return;
    _seenReaction = controller.reaction;
    final trigger = controller.lastTrigger;
    if (trigger != null) sink.fireTrigger(trigger.input);
  }
}

/// The Rive-drawn yak. A stub: see the library comment.
class RiveYak extends StatelessWidget {
  const RiveYak({
    super.key,
    required this.controller,
    required this.size,
    required this.width,
    this.semanticLabel,
  });

  /// Flips to true in the same change that adds `package:rive` and the
  /// `.riv` asset.
  static const bool runtimeAvailable = false;

  static bool get enabled => kRiveYakFlag && runtimeAvailable;

  final YakController controller;
  final double size;
  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Unreachable while [runtimeAvailable] is false: YakMascot checks
    // [enabled] first and draws the code yak instead.
    return SizedBox(width: width, height: size);
  }
}
