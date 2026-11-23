import 'package:bojang/theme/motion.dart';
import 'package:bojang/widgets/rive_yak.dart';
import 'package:bojang/widgets/yak_controller.dart';
import 'package:bojang/widgets/yak_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements YakInputSink {
  final log = <String>[];
  @override
  void fireTrigger(String name) => log.add('trig $name');
  @override
  void setNumber(String name, double value) => log.add('num $name=$value');
  @override
  void setBool(String name, bool value) => log.add('bool $name=$value');
}

void main() {
  group('YakController state machine', () {
    test('the contract names are fixed', () {
      expect(YakController.stateMachine, 'yak_sm');
      expect(YakController.riveAsset, 'assets/rive/yak.riv');
      expect(YakController.inputNames, [
        'correct_trig',
        'incorrect_trig',
        'correct_after_mistake_trig',
        'reset_trig',
        'idle_num',
        'dark_mode_bool',
        'reduced_motion_bool',
      ]);
    });

    test('each trigger moves to its reaction, reset goes to idle', () {
      final c = YakController();
      expect(c.state, YakState.idle);
      c.fire(YakTrigger.correct);
      expect(c.state, YakState.correct);
      c.fire(YakTrigger.incorrect);
      expect(c.state, YakState.incorrect, reason: 'newest trigger wins');
      c.fire(YakTrigger.correctAfterMistake);
      expect(c.state, YakState.correctAfterMistake);
      c.fire(YakTrigger.reset);
      expect(c.state, YakState.idle);
      expect(c.reaction, 4);
    });

    test('a reaction ends back at idle; a stale finish is ignored', () {
      final c = YakController();
      c.fire(YakTrigger.correct);
      final first = c.reaction;
      c.fire(YakTrigger.incorrect);
      c.finishReaction(first);
      expect(c.state, YakState.incorrect);
      c.finishReaction(c.reaction);
      expect(c.state, YakState.idle);
    });

    test('fireInput takes Rive names and rejects unknown ones', () {
      final c = YakController();
      expect(c.fireInput('correct_after_mistake_trig'), isTrue);
      expect(c.state, YakState.correctAfterMistake);
      expect(c.fireInput('dance_trig'), isFalse);
      expect(c.reaction, 1);
    });

    test('idle_num is clamped to the variants', () {
      final c = YakController();
      c.idleNum = 99;
      expect(c.idleNum, YakController.idleVariants - 1);
      c.idleNum = -3;
      expect(c.idleNum, 0);
    });

    test('environment: reduced_motion_bool is true below full motion', () {
      final c = YakController();
      var notified = 0;
      c.addListener(() => notified++);
      expect(
        c.syncEnvironment(darkMode: true, motion: MotionLevel.reduced),
        isTrue,
      );
      expect(c.darkMode, isTrue);
      expect(c.reducedMotion, isTrue);
      expect(
        c.syncEnvironment(darkMode: true, motion: MotionLevel.static),
        isFalse,
      );
      expect(notified, 0, reason: 'environment sync is silent');
    });

    test('reaction length follows Motion', () {
      final full = YakState.correctAfterMistake.duration;
      expect(
        YakController.reactionLength(
          YakState.correctAfterMistake,
          MotionLevel.full,
        ),
        full,
      );
      expect(
        YakController.reactionLength(
          YakState.correctAfterMistake,
          MotionLevel.reduced,
        ),
        full * 0.5,
      );
      expect(
        YakController.reactionLength(
          YakState.correctAfterMistake,
          MotionLevel.static,
        ),
        Duration.zero,
      );
      for (final s in YakState.values) {
        expect(s.duration, lessThan(const Duration(seconds: 1)));
      }
    });
  });

  group('RiveYakBinding', () {
    test('pushes inputs on attach and fires each trigger once', () {
      final c = YakController(idleNum: 1);
      final sink = _Sink();
      final b = RiveYakBinding(c, sink)..attach();
      expect(sink.log, [
        'num idle_num=1.0',
        'bool dark_mode_bool=false',
        'bool reduced_motion_bool=false',
      ]);
      sink.log.clear();
      c.fire(YakTrigger.correct);
      c.finishReaction(c.reaction); // back to idle: no new trigger
      c.fire(YakTrigger.reset);
      c.syncEnvironment(darkMode: true, motion: MotionLevel.full);
      b.syncInputs();
      expect(sink.log, [
        'trig correct_trig',
        'trig reset_trig',
        'bool dark_mode_bool=true',
      ]);
      b.detach();
      c.fire(YakTrigger.incorrect);
      expect(sink.log, hasLength(3));
    });

    test('the reaction-done event returns the controller to idle', () {
      final c = YakController();
      final b = RiveYakBinding(c, _Sink())..attach();
      c.fire(YakTrigger.incorrect);
      b.onRiveEvent(RiveYakBinding.reactionDoneEvent);
      expect(c.state, YakState.idle);
    });

    test('the Rive yak stays off until the runtime ships', () {
      expect(RiveYak.enabled, isFalse);
    });
  });

  group('code-drawn yak plays the contract', () {
    Future<void> pump(
      WidgetTester tester,
      YakController c, {
      bool reduce = false,
      bool dark = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Center(child: YakMascot(controller: c, size: 120)),
          ),
        ),
      );
    }

    testWidgets('each reaction plays and returns to idle', (tester) async {
      final c = YakController();
      await pump(tester, c);
      for (final t in [
        YakTrigger.correct,
        YakTrigger.incorrect,
        YakTrigger.correctAfterMistake,
      ]) {
        c.fire(t);
        await tester.pump();
        expect(c.state, isNot(YakState.idle));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(c.state, YakState.idle, reason: t.input);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('idle variants and dark mode paint', (tester) async {
      final c = YakController();
      await pump(tester, c, dark: true);
      expect(c.darkMode, isTrue);
      for (var i = 0; i < YakController.idleVariants; i++) {
        c.idleNum = i;
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('static motion: no movement, straight back to idle', (
      tester,
    ) async {
      final c = YakController();
      await pump(tester, c, reduce: true);
      expect(c.reducedMotion, isTrue);
      c.fire(YakTrigger.correct);
      await tester.pump();
      expect(c.state, YakState.idle);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a newer trigger interrupts a running reaction', (
      tester,
    ) async {
      final c = YakController();
      await pump(tester, c);
      c.fire(YakTrigger.correctAfterMistake);
      await tester.pump(const Duration(milliseconds: 200));
      c.fire(YakTrigger.incorrect);
      await tester.pump();
      expect(c.state, YakState.incorrect);
      await tester.pump(const Duration(seconds: 1));
      expect(c.state, YakState.idle);
    });
  });
}
