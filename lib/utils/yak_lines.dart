/// Everything the yak says, in one place, so its voice stays consistent.
///
/// Voice: the learner's biggest fan. Warm, a little playful, never scolding.
/// A miss gets encouragement, not disappointment. Tibetan phrases are short,
/// common ones a beginner will meet early, always paired with English.
///
/// Every picker takes a [seed] instead of using a random source, so a line
/// does not change under the learner when a screen rebuilds.
library;

import '../widgets/yak_mascot.dart';

/// A line plus the face that goes with it.
class YakLine {
  const YakLine(this.mood, this.title, [this.body]);

  final YakMood mood;

  /// Short headline — often a Tibetan phrase.
  final String title;
  final String? body;
}

class YakLines {
  YakLines._();

  /// The yak's name. ནོར་བུ (norbu) means "jewel", and ནོར (nor) is also the
  /// everyday Tibetan word for yaks and cattle as wealth.
  static const String name = 'Norbu';

  static T _pick<T>(List<T> options, int seed) =>
      options[seed.abs() % options.length];

  // ── Home ──────────────────────────────────────────────────────────

  static YakLine home({
    required DateTime now,
    required int streak,
    required bool practicedToday,
    required bool isNewLearner,
  }) {
    final seed = now.day + now.month * 31;

    if (isNewLearner) {
      return const YakLine(
        YakMood.waving,
        'བཀྲ་ཤིས་བདེ་ལེགས།',
        "Tashi delek! I'm $name. Let's learn Tibetan together.",
      );
    }

    if (practicedToday) {
      return _pick([
        YakLine(
          YakMood.proud,
          'ཡག་པོ་འདུག',
          streak > 1
              ? 'Yakpo du! $streak days in a row.'
              : "Yakpo du! Today's practice is done.",
        ),
        const YakLine(
          YakMood.proud,
          'ལེགས་སོ།',
          'Done for today. One more for fun?',
        ),
      ], seed);
    }

    if (streak > 0 && now.hour >= 19) {
      return YakLine(
        YakMood.encouraging,
        'Still time today',
        'One short lesson keeps your $streak-day streak.',
      );
    }

    if (streak > 1) {
      return YakLine(
        YakMood.waving,
        _hello(now),
        'Your $streak-day streak is waiting for you.',
      );
    }

    return _pick([
      YakLine(YakMood.waving, _hello(now), 'Ready for Tibetan?'),
      YakLine(YakMood.waving, _hello(now), 'Five minutes is all it takes.'),
      YakLine(YakMood.happy, _hello(now), 'Shall we learn a few words?'),
    ], seed);
  }

  static String _hello(DateTime now) {
    if (now.hour < 12) return 'སྔ་དྲོ་བདེ་ལེགས།';
    if (now.hour >= 18) return 'དགོང་དྲོ་བདེ་ལེགས།';
    return 'བཀྲ་ཤིས་བདེ་ལེགས།';
  }

  // ── Quiz ──────────────────────────────────────────────────────────

  /// [combo] is how many answers in a row were right, this one included.
  static YakLine correct({required int seed, int combo = 1}) {
    if (combo >= 3 && combo % 5 == 0) {
      return YakLine(YakMood.cheering, '$combo in a row!', "You're on fire.");
    }
    if (combo == 3) {
      return const YakLine(YakMood.cheering, '3 in a row!', 'Keep it going.');
    }
    return _pick(const [
      YakLine(YakMood.cheering, 'ལེགས་སོ། Amazing!'),
      YakLine(YakMood.cheering, 'ཡག་པོ་འདུག Yakpo du!'),
      YakLine(YakMood.proud, 'Nice one!'),
      YakLine(YakMood.cheering, 'ལེགས་སོ། Well done!'),
      YakLine(YakMood.proud, "That's right!"),
    ], seed);
  }

  static YakLine incorrect({required int seed}) {
    return _pick(const [
      YakLine(YakMood.encouraging, 'སེམས་ཤུགས་མ་ཆག — not quite'),
      YakLine(YakMood.encouraging, "Not quite — you'll get it"),
      YakLine(YakMood.encouraging, 'Almost! Keep going'),
    ], seed);
  }

  // ── Lesson complete ───────────────────────────────────────────────

  static YakLine lessonComplete({required double accuracy}) {
    if (accuracy >= 100) {
      return const YakLine(
        YakMood.cheering,
        'ལེགས་སོ། Perfect!',
        'Not a single miss. I am one proud yak.',
      );
    }
    if (accuracy >= 70) {
      return const YakLine(
        YakMood.cheering,
        'ལེགས་སོ། Excellent!',
        'That one is in the bag.',
      );
    }
    return const YakLine(
      YakMood.encouraging,
      'Keep practicing!',
      'Every yak climbs the pass one step at a time.',
    );
  }

  // ── Streak ────────────────────────────────────────────────────────

  static YakMood streakMood({required int streak, required bool practicedToday}) {
    if (practicedToday) return streak >= 7 ? YakMood.cheering : YakMood.proud;
    if (streak == 0) return YakMood.sleeping;
    return YakMood.encouraging;
  }

  // ── Waiting and trouble ───────────────────────────────────────────

  static const String loading = 'Fetching your lesson…';

  static const YakLine offline = YakLine(
    YakMood.sad,
    'I lost the trail',
    'Check your connection and try again.',
  );

  static const YakLine error = YakLine(
    YakMood.sad,
    'Something went wrong',
    "That wasn't you. Let's try once more.",
  );

  // ── Games ─────────────────────────────────────────────────────────

  static YakLine gameWon({required bool newBest}) {
    return newBest
        ? const YakLine(YakMood.cheering, 'New best!', 'ལེགས་སོ། What a round.')
        : const YakLine(YakMood.proud, 'Well played!', 'Go again?');
  }

  // ── Reminders ─────────────────────────────────────────────────────

  /// Daily reminder copy as (title, body), chosen by the day it is
  /// scheduled for.
  static (String, String) reminder(DateTime day) {
    return _pick(const [
      ('བཀྲ་ཤིས་བདེ་ལེགས། $name here', 'Five minutes of Tibetan today?'),
      ('Your yak is waiting', "A short lesson keeps your streak alive."),
      ("Let's learn a few words", '$name saved you a spot. Tap to start.'),
      ('ཡག་པོ་འདུག — time to practice', 'One lesson today, one step closer.'),
    ], day.day + day.month * 31);
  }
}
