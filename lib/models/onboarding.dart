/// Onboarding for new installs (plan items #8 and #9): the questions, their
/// answers as stored in user_kv (namespace `onboarding`), and the self-report
/// placement that turns the knowledge answer into a starting level.
library;

/// Why the learner is here. Stored as `onboarding/motivation`.
enum Motivation {
  heritage('Heritage and family', 'Talk with family, keep the language alive'),
  buddhist('Buddhist study', 'Read prayers, texts and teachings'),
  travel('Travel', 'Get around Tibet, Nepal, India or Bhutan'),
  curious('Just curious', 'I like learning new languages');

  final String title;
  final String subtitle;
  const Motivation(this.title, this.subtitle);

  static Motivation? fromId(Object? id) => _byName(values, id);
}

/// How much Tibetan the learner says they know. Stored as
/// `onboarding/prior_knowledge`; sets the starting level ([Placement]).
enum PriorKnowledge {
  none('I\'m new to Tibetan', 'Start with the alphabet'),
  speakSome('I can speak a little', 'Some words and phrases, no script'),
  canRead('I can read the script', 'I know the letters and syllables'),
  conversational('I can hold a conversation', 'I speak it, I want more words');

  final String title;
  final String subtitle;
  const PriorKnowledge(this.title, this.subtitle);

  /// The id stored in user_kv and sent with analytics.
  String get id => switch (this) {
    PriorKnowledge.none => 'none',
    PriorKnowledge.speakSome => 'speak_some',
    PriorKnowledge.canRead => 'can_read',
    PriorKnowledge.conversational => 'conversational',
  };

  static PriorKnowledge? fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// Lessons a day the learner aims for. Stored as `onboarding/daily_goal`
/// (the number of lessons); `GET /learn/path` reads it as sessions a day for
/// the daily goal ring.
enum DailyGoal {
  easy(1, 'Easy does it'),
  steady(2, 'Steady'),
  keen(3, 'Keen'),
  serious(5, 'Serious');

  final int lessons;
  final String title;
  const DailyGoal(this.lessons, this.title);

  String get subtitle =>
      lessons == 1 ? '1 lesson a day' : '$lessons lessons a day';

  static DailyGoal? fromLessons(Object? lessons) {
    for (final value in values) {
      if (value.lessons == lessons) return value;
    }
    return null;
  }
}

/// The onboarding screens, in order. The notification primer used to be the
/// last; it now follows the first finished lesson (NotificationPrimer).
enum OnboardingStep { hello, motivation, knowledge, voice, goal }

T? _byName<T extends Enum>(List<T> values, Object? id) {
  for (final value in values) {
    if (value.name == id) return value;
  }
  return null;
}

/// The keys written to user_kv namespace `onboarding`. Other features read
/// them: `GET /learn/path` reads [startLevel] to mark the active node.
class OnboardingKeys {
  OnboardingKeys._();

  static const String motivation = 'motivation';
  static const String priorKnowledge = 'prior_knowledge';
  static const String voice = 'voice';
  static const String dailyGoal = 'daily_goal';
  /// The old onboarding primer's answer (`allowed`/`refused`/`maybe_later`),
  /// kept on installs that saw it. No longer written.
  static const String notifications = 'notifications';

  /// The level id the path starts at (`onboarding/start_level`).
  static const String startLevel = 'start_level';

  /// ISO-8601 UTC time the flow finished, or was skipped.
  static const String completedAt = 'completed_at';

  /// `completed` or `skipped`.
  static const String outcome = 'outcome';
}

/// Self-report placement: the knowledge answer alone picks the first level.
/// No test; levels before the start stay open, so a learner who placed too
/// high can go back.
class Placement {
  Placement._();

  /// Basics unit (`tibetan-basics`): the first letters lesson.
  static const String basicsStart = 'basics-letters-1';

  /// Basics after its script lessons (letters through reading whole
  /// words): numbers, greetings and first phrases.
  static const String basicsWords = 'basics-numbers';

  /// The first word unit after Basics (`vocab-categories`), as ordered on
  /// the server today. [resolve] prefers the live level list when it has it.
  static const String firstWordUnit = 'vocab-action';

  /// Basics' unit id prefix: every Basics level id starts with it.
  static const String basicsPrefix = 'basics-';

  /// The start level for [knowledge] (null = skipped the question: start
  /// at the beginning).
  static String startLevelFor(PriorKnowledge? knowledge) => switch (knowledge) {
    null || PriorKnowledge.none => basicsStart,
    PriorKnowledge.canRead => basicsWords,
    PriorKnowledge.speakSome || PriorKnowledge.conversational => firstWordUnit,
  };

  /// [startLevelFor], checked against the live level ids in path order.
  /// When the fixed id is missing (the curriculum changed), speakers start
  /// at the first level outside Basics and everyone else at the first level.
  static String resolve(PriorKnowledge? knowledge, List<String> levelIds) {
    final wanted = startLevelFor(knowledge);
    if (levelIds.isEmpty || levelIds.contains(wanted)) return wanted;
    if (wanted == firstWordUnit) {
      for (final id in levelIds) {
        if (!id.startsWith(basicsPrefix)) return id;
      }
    }
    return levelIds.first;
  }
}

/// Whether onboarding may show, decided once per install and stored.
enum OnboardingStatus {
  /// Started and not finished: shown again on the next launch.
  inProgress,
  done,
  skipped,

  /// The install was in use before onboarding shipped: never shown.
  existing;

  static OnboardingStatus? fromId(String? id) => _byName(values, id);

  bool get isFinal => this != OnboardingStatus.inProgress;
}

/// Who sees onboarding: only a brand-new install.
class OnboardingGate {
  OnboardingGate._();

  /// Device storage keys that only appear once someone has used the app:
  /// progress, streaks, a finished lesson or a signed-in account.
  static const Set<String> usageKeys = {
    'total_quizzes',
    'total_correct',
    'xp',
    'current_streak',
    'last_play_date',
    'play_dates',
    'lessons_completed',
    'category_progress',
    'cached_user',
    'notification_primer_asks',
  };

  static bool isExistingInstall({
    required Set<String> storedKeys,
    bool hadAccount = false,
  }) => hadAccount || storedKeys.any(usageKeys.contains);

  /// Whether to open onboarding now. [enabled] is the server kill switch
  /// (`onboarding`); [status] what this install stored before.
  static bool shouldShow({
    required bool enabled,
    required OnboardingStatus? status,
    required bool existingInstall,
  }) {
    if (!enabled) return false;
    if (status != null) return !status.isFinal;
    return !existingInstall;
  }
}
