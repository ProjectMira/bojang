import 'word_of_the_day.dart';

/// The four parts of the day the home-screen widget changes with (plan #25):
/// Norbu is relaxed all day, then a little keener as midnight gets closer.
enum WidgetDayPart {
  /// Midnight to 4 pm.
  day,

  /// 4 pm to 8 pm.
  evening,

  /// 8 pm to 10 pm.
  late,

  /// 10 pm to midnight: the last call.
  lastCall;

  static WidgetDayPart at(DateTime local) {
    final h = local.hour;
    if (h < 16) return WidgetDayPart.day;
    if (h < 20) return WidgetDayPart.evening;
    if (h < 22) return WidgetDayPart.late;
    return WidgetDayPart.lastCall;
  }

  /// The key the native widgets read (`line_<key>`).
  String get key => switch (this) {
    WidgetDayPart.day => 'day',
    WidgetDayPart.evening => 'evening',
    WidgetDayPart.late => 'late',
    WidgetDayPart.lastCall => 'last_call',
  };
}

/// Streak state shown on the widget.
enum WidgetStreakState {
  /// No streak yet (or it lapsed with nothing to win back).
  none,

  /// A live streak.
  active,

  /// A streak freeze covered yesterday.
  frozen,

  /// The streak broke and an Earn Back window is open.
  earnBack;

  String get key => switch (this) {
    WidgetStreakState.none => 'none',
    WidgetStreakState.active => 'active',
    WidgetStreakState.frozen => 'frozen',
    WidgetStreakState.earnBack => 'earn_back',
  };
}

/// Everything the native widgets show, as flat key/value pairs written with
/// `home_widget` (Android SharedPreferences, iOS App Group UserDefaults).
///
/// The widget redraws on its own between app opens (every 30 minutes on
/// Android, on the iOS timeline), so the part of day and "done today" are
/// worked out natively from the clock: the app writes one line per part of
/// the day and the local date practice last happened.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.streak,
    required this.state,
    required this.todayDone,
    required this.today,
    required this.lastDoneDate,
    required this.word,
    required this.dayPart,
    required this.lines,
    this.earnBackStreak = 0,
  });

  final int streak;
  final WidgetStreakState state;
  final bool todayDone;

  /// Local date (yyyy-mm-dd) the snapshot was made.
  final String today;

  /// Local date of the last practice, or '' when none.
  final String lastDoneDate;
  final DailyWord word;
  final WidgetDayPart dayPart;

  /// One headline per part of day, plus `done`.
  final Map<String, String> lines;
  final int earnBackStreak;

  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  factory WidgetSnapshot.build({
    required DateTime now,
    required int streak,
    DateTime? lastPlayDate,
    List<DateTime> frozenDates = const [],
    int? earnBackStreak,
  }) {
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final todayDone = lastPlayDate != null && _sameDay(lastPlayDate, now);
    final state =
        earnBackStreak != null && earnBackStreak > 0 && streak == 0
            ? WidgetStreakState.earnBack
            : streak <= 0
            ? WidgetStreakState.none
            : frozenDates.any((d) => _sameDay(d, yesterday)) && !todayDone
            ? WidgetStreakState.frozen
            : WidgetStreakState.active;
    return WidgetSnapshot(
      streak: streak,
      state: state,
      todayDone: todayDone,
      today: isoDay(now),
      lastDoneDate: lastPlayDate == null ? '' : isoDay(lastPlayDate),
      word: WordOfTheDay.forDay(now),
      dayPart: WidgetDayPart.at(now),
      lines: linesFor(state, streak, earnBackStreak ?? 0),
      earnBackStreak: earnBackStreak ?? 0,
    );
  }

  /// Norbu's widget copy (original), one line per part of day.
  static Map<String, String> linesFor(
    WidgetStreakState state,
    int streak,
    int earnBackStreak,
  ) {
    String days(int n) => n == 1 ? '1 day' : '$n days';
    switch (state) {
      case WidgetStreakState.none:
        return {
          'day': 'Norbu has a word for you',
          'evening': 'A first lesson starts a streak',
          'late': 'Five minutes starts a streak',
          'last_call': 'Still time to start today',
          'done': 'Nice! See you tomorrow',
        };
      case WidgetStreakState.earnBack:
        return {
          'day': 'Win back your ${days(earnBackStreak)}',
          'evening': 'Earn Back is open',
          'late': 'One lesson closer to ${days(earnBackStreak)}',
          'last_call': 'Earn Back: a lesson before midnight',
          'done': 'Good progress on Earn Back',
        };
      case WidgetStreakState.frozen:
        return {
          'day': 'A freeze kept your streak safe',
          'evening': 'Streak safe. Add today?',
          'late': 'Keep the ice for another day',
          'last_call': 'One lesson before midnight',
          'done': 'Back on track. Lekso!',
        };
      case WidgetStreakState.active:
        return {
          'day': '${days(streak)} and counting',
          'evening': 'Day ${streak + 1} is waiting',
          'late': 'Norbu is keeping watch',
          'last_call': 'Last call for day ${streak + 1}',
          'done': 'Done today. Lekso!',
        };
    }
  }

  /// The flat data the widgets read. Keys are part of the native contract
  /// (see `android/.../BojangStreakWidget.kt` and `ios/BojangWidget/`).
  Map<String, Object> toWidgetData() => {
    'streak': streak,
    'streak_state': state.key,
    'today_done': todayDone,
    'today': today,
    'last_done_date': lastDoneDate,
    'day_part': dayPart.key,
    'word_tibetan': word.tibetan,
    'word_phonetic': word.phonetic,
    'word_english': word.english,
    'earn_back_streak': earnBackStreak,
    for (final e in lines.entries) 'line_${e.key}': e.value,
  };
}
