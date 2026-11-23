import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/romanisation.dart';
import '../widgets/app_text_style.dart';
import '../widgets/yak_mascot.dart';
import '../theme/app_tokens.dart';
import 'analytics.dart';
import 'user_kv.dart';

/// The rules of reading help's wean-off (plan item #7), kept pure for tests.
class WeanOffPolicy {
  WeanOffPolicy._();

  /// Correct answers that make a word "known": its reading is then hidden
  /// under "new words only".
  static const int knownAfter = 2;

  /// Script questions answered right in a row, with reading help shown,
  /// before the one-time "turn off reading help?" suggestion.
  static const int suggestAfter = 20;

  /// The `tips` key (user_kv) marking the suggestion as shown.
  static const String tipKey = 'reading_help_wean_off';

  /// The run after one answer: a right answer with help shown adds one, a
  /// wrong one resets it, and an answer with no help shown leaves it.
  static int nextRun(
    int run, {
    required bool correct,
    required bool helpShown,
  }) {
    if (!correct) return 0;
    return helpShown ? run + 1 : run;
  }

  static bool shouldSuggest({
    required int run,
    required bool alreadyShown,
    required TransliterationMode mode,
  }) => !alreadyShown && mode != TransliterationMode.off && run >= suggestAfter;
}

/// Reading help beyond the phonetics/Wylie choice: "new words only" (hide a
/// word's reading once it has been answered right [WeanOffPolicy.knownAfter]
/// times) and the one-time suggestion to turn reading help off.
///
/// Word counts stay on the device. [RomanisationText] listens to this.
class ReadingHelp extends ChangeNotifier {
  ReadingHelp({SeenTips? tips}) : _tips = tips;

  static ReadingHelp instance = ReadingHelp();

  static const String newWordsOnlyKey = 'reading_help_new_words_only';
  static const String countsKey = 'reading_help_correct_counts';
  static const String runKey = 'reading_help_right_run';

  /// Words remembered at most; the oldest are forgotten first.
  static const int maxWords = 3000;

  final SeenTips? _tips;
  SeenTips get tips => _tips ?? SeenTips();

  bool _loaded = false;
  bool _newWordsOnly = false;
  int _run = 0;
  bool _suggestionDue = false;
  final Map<String, int> _counts = {};

  bool get newWordsOnly => _newWordsOnly;
  int get run => _run;

  /// The 20-in-a-row moment was reached and the tip was never shown; the
  /// session end shows it ([maybeSuggest]).
  bool get suggestionDue => _suggestionDue;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _newWordsOnly = prefs.getBool(newWordsOnlyKey) ?? false;
      _run = prefs.getInt(runKey) ?? 0;
      final raw = prefs.getString(countsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            if (e.value is int) _counts[e.key.toString()] = e.value as int;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Reading help state unreadable: $e');
    }
  }

  /// A word's identity: its Wylie, else its phonetics.
  static String? keyOf(Romanisation r) {
    if (r.wylie.isNotEmpty) return 'w:${r.wylie}';
    if (r.phonetic.isNotEmpty) return 'p:${r.phonetic}';
    return null;
  }

  bool isKnown(Romanisation r) {
    final key = keyOf(r);
    return key != null && (_counts[key] ?? 0) >= WeanOffPolicy.knownAfter;
  }

  /// Whether the reading of [r] is hidden by "new words only".
  bool hides(Romanisation r) => _newWordsOnly && isKnown(r);

  Future<void> setNewWordsOnly(bool value, {String source = 'settings'}) async {
    if (_newWordsOnly == value) return;
    _newWordsOnly = value;
    notifyListeners();
    Analytics.track('reading_help_new_words_only_changed', {
      'enabled': value,
      'source': source,
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(newWordsOnlyKey, value);
    } catch (_) {}
  }

  /// Records one answered question. [helpShownBefore] is whether the
  /// reading was on screen while the learner chose (the quiz hides it on
  /// script questions until answered).
  Future<void> recordAnswer(
    Romanisation word, {
    required bool correct,
    required TransliterationMode mode,
    bool hiddenUntilAnswered = false,
  }) async {
    final helpShown =
        mode != TransliterationMode.off &&
        !hiddenUntilAnswered &&
        word.linesFor(mode).isNotEmpty &&
        !hides(word);
    final key = keyOf(word);
    if (correct && key != null) {
      final count = (_counts.remove(key) ?? 0) + 1;
      _counts[key] = count; // re-inserted last: the most recent
      while (_counts.length > maxWords) {
        _counts.remove(_counts.keys.first);
      }
    }
    _run = WeanOffPolicy.nextRun(_run, correct: correct, helpShown: helpShown);
    if (!_suggestionDue &&
        WeanOffPolicy.shouldSuggest(
          run: _run,
          alreadyShown: await _seen(),
          mode: mode,
        )) {
      _suggestionDue = true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(runKey, _run);
      if (correct) await prefs.setString(countsKey, jsonEncode(_counts));
    } catch (_) {}
  }

  Future<bool> _seen() async {
    try {
      return await tips.hasSeen(WeanOffPolicy.tipKey);
    } catch (_) {
      return false;
    }
  }

  /// The session-end ask: shows the suggestion once, when due. Returns
  /// whether it showed. [currentMode] and [setMode] read and change the
  /// learner's reading help (ThemeService in the app).
  Future<bool> maybeSuggest(
    BuildContext context, {
    required TransliterationMode currentMode,
    required Future<void> Function(TransliterationMode mode) setMode,
  }) async {
    if (!_suggestionDue) return false;
    _suggestionDue = false;
    if (currentMode == TransliterationMode.off || await _seen()) return false;
    if (!context.mounted) return false;
    final answer = showWeanOffSheet(context);
    await tips.markSeen(WeanOffPolicy.tipKey);
    Analytics.track('reading_help_wean_off_shown', {
      'run': _run,
      'mode': currentMode.name,
      'new_words_only': _newWordsOnly,
    });
    final choice = await answer ?? 'keep';
    Analytics.track('reading_help_wean_off_answered', {'choice': choice});
    if (choice == 'off') await setMode(TransliterationMode.off);
    if (choice == 'new_words') await setNewWordsOnly(true, source: 'wean_off');
    return true;
  }

  /// "You're reading well": returns `off`, `new_words` or `keep` (null when
  /// dismissed).
  static Future<String?> showWeanOffSheet(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      routeSettings: const RouteSettings(name: 'reading_help_wean_off'),
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface(context),
      builder:
          (context) => SafeArea(
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const YakMascot(mood: YakMood.proud, size: 96),
                      const SizedBox(height: 12),
                      Text(
                        'You\'re reading well!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${WeanOffPolicy.suggestAfter} right in a row with reading '
                        'help on. Try the Tibetan script on its own? You can turn '
                        'the help back on in Settings any time.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          context,
                          color: AppTokens.inkSoft(context),
                        ).copyWith(fontSize: 15, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('wean_off_turn_off'),
                          onPressed: () => Navigator.pop(context, 'off'),
                          child: const Text('Turn off reading help'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          key: const ValueKey('wean_off_new_words'),
                          onPressed: () => Navigator.pop(context, 'new_words'),
                          child: const Text('Only for new words'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        key: const ValueKey('wean_off_keep'),
                        onPressed: () => Navigator.pop(context, 'keep'),
                        child: const Text('Keep it on'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  @visibleForTesting
  void debugReset() {
    _loaded = false;
    _newWordsOnly = false;
    _run = 0;
    _suggestionDue = false;
    _counts.clear();
  }
}
