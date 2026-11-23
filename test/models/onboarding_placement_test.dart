import 'package:bojang/models/onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Placement (self-report, plan #9)', () {
    test('none starts at the first Basics letters lesson', () {
      expect(Placement.startLevelFor(PriorKnowledge.none), 'basics-letters-1');
    });

    test('a skipped question starts at the beginning too', () {
      expect(Placement.startLevelFor(null), Placement.basicsStart);
    });

    test('can read skips the Basics script lessons', () {
      expect(Placement.startLevelFor(PriorKnowledge.canRead), 'basics-numbers');
    });

    test('speakers start at the first word unit after Basics', () {
      expect(Placement.startLevelFor(PriorKnowledge.speakSome), 'vocab-action');
      expect(
        Placement.startLevelFor(PriorKnowledge.conversational),
        'vocab-action',
      );
    });

    const live = [
      'basics-letters-1',
      'basics-letters-2',
      'basics-reading',
      'basics-numbers',
      'basics-greetings',
      'vocab-action',
      'vocab-animals',
    ];

    test('resolve keeps the fixed id when the live list has it', () {
      for (final k in PriorKnowledge.values) {
        expect(Placement.resolve(k, live), Placement.startLevelFor(k));
      }
    });

    test(
      'resolve falls back to the first level outside Basics for speakers',
      () {
        const changed = [
          'basics-letters-1',
          'basics-numbers',
          'vocab-greetings',
        ];
        expect(
          Placement.resolve(PriorKnowledge.conversational, changed),
          'vocab-greetings',
        );
      },
    );

    test('resolve falls back to the first level otherwise', () {
      const changed = ['letters-a', 'letters-b'];
      expect(Placement.resolve(PriorKnowledge.canRead, changed), 'letters-a');
      expect(
        Placement.resolve(PriorKnowledge.none, const []),
        'basics-letters-1',
      );
    });

    test('answer ids round-trip', () {
      for (final k in PriorKnowledge.values) {
        expect(PriorKnowledge.fromId(k.id), k);
      }
      expect(PriorKnowledge.speakSome.id, 'speak_some');
      expect(Motivation.fromId('buddhist'), Motivation.buddhist);
      expect(DailyGoal.fromLessons(5), DailyGoal.serious);
    });
  });

  group('OnboardingGate', () {
    test('a fresh install sees onboarding', () {
      expect(
        OnboardingGate.shouldShow(
          enabled: true,
          status: null,
          existingInstall: OnboardingGate.isExistingInstall(
            storedKeys: {'server_config_v1', 'theme_mode'},
          ),
        ),
        isTrue,
      );
    });

    test('an install with progress or an account never does', () {
      expect(
        OnboardingGate.isExistingInstall(storedKeys: {'xp', 'theme_mode'}),
        isTrue,
      );
      expect(
        OnboardingGate.isExistingInstall(storedKeys: {}, hadAccount: true),
        isTrue,
      );
      expect(
        OnboardingGate.shouldShow(
          enabled: true,
          status: null,
          existingInstall: true,
        ),
        isFalse,
      );
      expect(
        OnboardingGate.shouldShow(
          enabled: true,
          status: OnboardingStatus.existing,
          existingInstall: false,
        ),
        isFalse,
      );
    });

    test('unfinished onboarding shows again; finished never', () {
      expect(
        OnboardingGate.shouldShow(
          enabled: true,
          status: OnboardingStatus.inProgress,
          existingInstall: true,
        ),
        isTrue,
      );
      for (final s in [OnboardingStatus.done, OnboardingStatus.skipped]) {
        expect(
          OnboardingGate.shouldShow(
            enabled: true,
            status: s,
            existingInstall: false,
          ),
          isFalse,
        );
      }
    });

    test('the kill switch wins', () {
      expect(
        OnboardingGate.shouldShow(
          enabled: false,
          status: null,
          existingInstall: false,
        ),
        isFalse,
      );
    });
  });

  group('DailyGoal (onboarding/daily_goal)', () {
    test('stores lessons a day, the unit GET /learn/path counts in', () {
      // The path reads a bare number as sessions a day (not minutes), so
      // "Keen" (3) is a ring of 3 sessions.
      expect(DailyGoal.values.map((g) => g.lessons), [1, 2, 3, 5]);
      expect(DailyGoal.fromLessons(3), DailyGoal.keen);
      expect(DailyGoal.fromLessons(10), isNull);
    });
  });
}
