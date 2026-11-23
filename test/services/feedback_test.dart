import 'dart:io';

import 'package:bojang/services/feedback.dart';
import 'package:bojang/theme/motion.dart';
import 'package:bojang/widgets/yak_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Recorder implements FeedbackOutputs {
  final sounds = <String>[];
  final volumes = <double>[];
  final haptics = <HapticKind>[];
  final waits = <Duration>[];

  @override
  Future<void> sound(
    String asset, {
    required double volume,
    required bool ui,
  }) async {
    sounds.add(asset);
    volumes.add(volume);
  }

  @override
  Future<void> haptic(HapticKind kind) async => haptics.add(kind);

  @override
  Future<void> wait(Duration duration) async => waits.add(duration);
}

const _allOn = FeedbackEnv(soundOn: true, hapticsOn: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Recorder out;

  setUp(() {
    out = _Recorder();
    Feedback.outputs = out;
    Feedback.session.reset();
    SharedPreferences.setMockInitialValues({});
    Feedback.haptics.resetForTest();
  });

  group('event table', () {
    test('every event has a sound file that ships, and a haptic', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final e in FeedbackEvent.values) {
        final cue = Feedback.cueFor(e);
        expect(cue.sound, isNotNull, reason: e.id);
        expect(File('assets/${cue.sound}').existsSync(), isTrue, reason: e.id);
        expect(pubspec, contains('assets/${cue.sound}'), reason: e.id);
        expect(cue.haptic, isNotEmpty, reason: e.id);
      }
      for (var s = 0; s < Feedback.correctSteps; s++) {
        final sound = Feedback.correctSound(s);
        expect(File('assets/$sound').existsSync(), isTrue, reason: sound);
        expect(pubspec, contains('assets/$sound'));
      }
    });

    test('answer events drive the matching yak triggers', () {
      expect(Feedback.cueFor(FeedbackEvent.correct).yak, YakTrigger.correct);
      expect(
        Feedback.cueFor(FeedbackEvent.incorrect).yak,
        YakTrigger.incorrect,
      );
      expect(
        Feedback.cueFor(FeedbackEvent.correctAfterMistake).yak,
        YakTrigger.correctAfterMistake,
      );
      expect(
        Feedback.cueFor(FeedbackEvent.lessonComplete).yak,
        YakTrigger.reset,
      );
      expect(Feedback.cueFor(FeedbackEvent.tap).yak, isNull);
    });

    test('ids are the shared snake_case names', () {
      expect(FeedbackEvent.values.map((e) => e.id), [
        'correct',
        'incorrect',
        'correct_after_mistake',
        'lesson_complete',
        'streak_extended',
        'tier_up',
        'tap',
        'select',
      ]);
    });

    test('bigger moments get longer haptic sequences', () {
      int len(FeedbackEvent e) => Feedback.cueFor(e).haptic.length;
      expect(len(FeedbackEvent.correct), 1);
      expect(len(FeedbackEvent.lessonComplete), greaterThan(1));
      expect(
        len(FeedbackEvent.tierUp),
        greaterThan(len(FeedbackEvent.streakExtended)),
      );
    });

    test('a wrong answer is quieter than a right one', () {
      expect(
        Feedback.cueFor(FeedbackEvent.incorrect).volume,
        lessThan(Feedback.cueFor(FeedbackEvent.correct).volume),
      );
    });
  });

  group('playWith fires all three senses', () {
    test('correct: sound, light haptic, yak hop', () async {
      final before = Feedback.yak.reaction;
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      expect(out.sounds, ['audio/correct.mp3']);
      expect(out.haptics, [HapticKind.light]);
      expect(Feedback.yak.reaction, before + 1);
      expect(Feedback.yak.lastTrigger, YakTrigger.correct);
    });

    test('lesson complete plays its whole haptic sequence with gaps', () async {
      await Feedback.playWith(FeedbackEvent.lessonComplete, _allOn);
      expect(out.haptics, [
        HapticKind.medium,
        HapticKind.light,
        HapticKind.heavy,
      ]);
      expect(out.waits, hasLength(2));
    });
  });

  group('escalation', () {
    test('the correct chime rises a step per right answer, capped', () async {
      for (var i = 0; i < 7; i++) {
        await Feedback.playWith(FeedbackEvent.correct, _allOn);
      }
      expect(out.sounds, [
        'audio/correct.mp3',
        'audio/correct_1.mp3',
        'audio/correct_2.mp3',
        'audio/correct_3.mp3',
        'audio/correct_4.mp3',
        'audio/correct_4.mp3',
        'audio/correct_4.mp3',
      ]);
    });

    test(
      'a mistake resets it and the next right answer is a recovery',
      () async {
        await Feedback.answer(true); // step 0, no context: sound off
        await Feedback.playWith(FeedbackEvent.correct, _allOn); // step 1
        expect(out.sounds.last, 'audio/correct_1.mp3');
        expect(Feedback.session.resolve(false), FeedbackEvent.incorrect);
        await Feedback.playWith(FeedbackEvent.incorrect, _allOn);
        expect(Feedback.session.run, 0);
        expect(
          Feedback.session.resolve(true),
          FeedbackEvent.correctAfterMistake,
        );
        await Feedback.playWith(FeedbackEvent.correctAfterMistake, _allOn);
        expect(out.sounds.last, 'audio/correct_after_mistake.mp3');
        // The recovery counted as the first in a new run.
        expect(Feedback.session.resolve(true), FeedbackEvent.correct);
        await Feedback.playWith(FeedbackEvent.correct, _allOn);
        expect(out.sounds.last, 'audio/correct_1.mp3');
      },
    );

    test('lesson complete and startLesson reset the run', () async {
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      await Feedback.playWith(FeedbackEvent.lessonComplete, _allOn);
      expect(Feedback.session.run, 0);
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      Feedback.startLesson();
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      expect(out.sounds.last, 'audio/correct.mp3');
    });

    test('taps do not break a run', () async {
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      await Feedback.playWith(FeedbackEvent.tap, _allOn);
      await Feedback.playWith(FeedbackEvent.select, _allOn);
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      expect(out.sounds.last, 'audio/correct_1.mp3');
    });
  });

  group('toggles and motion', () {
    test('sound off: haptic and yak only', () async {
      final before = Feedback.yak.reaction;
      await Feedback.playWith(
        FeedbackEvent.correct,
        const FeedbackEnv(soundOn: false, hapticsOn: true),
      );
      expect(out.sounds, isEmpty);
      expect(out.haptics, [HapticKind.light]);
      expect(Feedback.yak.reaction, before + 1);
    });

    test('haptics off: sound only', () async {
      await Feedback.playWith(
        FeedbackEvent.tierUp,
        const FeedbackEnv(soundOn: true, hapticsOn: false),
      );
      expect(out.sounds, ['audio/tier_up.mp3']);
      expect(out.haptics, isEmpty);
    });

    test('escalation still advances with sound off', () async {
      const quiet = FeedbackEnv(soundOn: false, hapticsOn: false);
      await Feedback.playWith(FeedbackEvent.correct, quiet);
      await Feedback.playWith(FeedbackEvent.correct, quiet);
      await Feedback.playWith(FeedbackEvent.correct, _allOn);
      expect(out.sounds, ['audio/correct_2.mp3']);
    });

    test('volume scales with Settings and mutes at zero', () async {
      await Feedback.playWith(
        FeedbackEvent.incorrect,
        const FeedbackEnv(soundOn: true, volume: 0.5, hapticsOn: false),
      );
      expect(out.volumes.single, closeTo(0.3, 1e-9));
      await Feedback.playWith(
        FeedbackEvent.correct,
        const FeedbackEnv(soundOn: true, volume: 0, hapticsOn: false),
      );
      expect(out.sounds, hasLength(1));
    });

    test('reduced and static motion collapse sequences to one pulse', () async {
      for (final motion in [MotionLevel.reduced, MotionLevel.static]) {
        out.haptics.clear();
        await Feedback.playWith(
          FeedbackEvent.tierUp,
          FeedbackEnv(soundOn: false, hapticsOn: true, motion: motion),
        );
        expect(out.haptics, [HapticKind.light], reason: motion.name);
      }
    });

    test('the haptics switch is saved and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final setting = HapticsSetting();
      await setting.load();
      expect(setting.value, isTrue);
      await setting.set(false);
      final again = HapticsSetting();
      await again.load();
      expect(again.value, isFalse);
    });

    test('play() honours the saved haptics switch', () async {
      SharedPreferences.setMockInitialValues({HapticsSetting.prefsKey: false});
      Feedback.haptics.resetForTest();
      await Feedback.play(FeedbackEvent.correct);
      expect(out.haptics, isEmpty);
      SharedPreferences.setMockInitialValues({});
      Feedback.haptics.resetForTest();
      await Feedback.play(FeedbackEvent.correct);
      expect(out.haptics, [HapticKind.light]);
    });
  });
}
