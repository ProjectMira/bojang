import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth_screen.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import '../widgets/yak_mascot.dart';
import 'analytics.dart';
import 'app_config.dart';
import 'feature_flags.dart';

/// The moment the ask refers to.
enum SaveProgressMoment { firstLesson, streak, later }

/// When "save your progress" may show (plan item #19): only for a learner
/// without a real account, from the first finished lesson or a 3-day
/// streak, at most [maxAsks] times, [minGap] apart.
class SaveProgressPolicy {
  SaveProgressPolicy._();

  static const int maxAsks = 3;
  static const Duration minGap = Duration(days: 4);
  static const int streakDays = 3;

  /// The moment for this session end, or null when it is not one.
  /// The first lesson, a 3-day streak, and any lesson end after the first
  /// (a learner the primer kept from seeing the first-lesson ask).
  static SaveProgressMoment? momentFor({
    required int lessonsCompleted,
    required int streak,
  }) {
    if (streak >= streakDays) return SaveProgressMoment.streak;
    if (lessonsCompleted == 1) return SaveProgressMoment.firstLesson;
    if (lessonsCompleted > 1) return SaveProgressMoment.later;
    return null;
  }

  static bool shouldAsk({
    required bool needsAccount,
    required bool canOffer,
    required int asks,
    required DateTime? lastAsk,
    required DateTime now,
  }) {
    if (!needsAccount || !canOffer || asks >= maxAsks) return false;
    if (lastAsk != null && now.difference(lastAsk) < minGap) return false;
    return true;
  }
}

/// A soft "Save your progress" sheet at the session end, below the
/// notification primer (`LessonCompleteScreen.asks`). It never blocks a
/// lesson: it shows only after one, and "Not now" always closes it.
/// "Save my progress" opens the account screen, which links the anonymous
/// account in place (email, and Apple/Google only where the app shows them).
class SaveProgressPrompt {
  SaveProgressPrompt({
    bool Function()? needsAccount,
    bool Function()? canOffer,
    bool Function()? enabled,
    Future<bool?> Function(BuildContext, SaveProgressMoment)? present,
    Future<bool> Function(BuildContext)? openAccount,
    DateTime Function()? clock,
  }) : _needsAccount = needsAccount ?? _defaultNeedsAccount,
       _canOffer = canOffer ?? _defaultCanOffer,
       _enabled =
           enabled ?? (() => FeatureFlags.instance.isEnabled(killSwitch)),
       _present = present ?? _showSheet,
       _openAccount = openAccount ?? _defaultOpenAccount,
       _clock = clock ?? DateTime.now;

  static SaveProgressPrompt instance = SaveProgressPrompt();

  static const String killSwitch = 'account_linking';
  static const String asksKey = 'save_progress_asks';
  static const String lastAskKey = 'save_progress_last_ask_ms';

  final bool Function() _needsAccount;
  final bool Function() _canOffer;
  final bool Function() _enabled;
  final Future<bool?> Function(BuildContext, SaveProgressMoment) _present;
  final Future<bool> Function(BuildContext) _openAccount;
  final DateTime Function() _clock;
  bool _showing = false;

  /// Learners on the automatic anonymous account (or none, offline). Needs
  /// Firebase, which every way of saving progress goes through.
  static bool _defaultNeedsAccount() {
    try {
      if (Firebase.apps.isEmpty) return false;
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      return user == null || user.isAnonymous;
    } catch (_) {
      return false;
    }
  }

  static bool _defaultCanOffer() =>
      AppConfig.emailSignInEnabled ||
      AppConfig.appleSignInEnabled ||
      AppConfig.googleSignInEnabled;

  static Future<bool> _defaultOpenAccount(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'auth'),
        fullscreenDialog: true,
        builder:
            (_) => const AuthScreen(
              returnWhenDone: true,
              startCreatingAccount: true,
            ),
      ),
    );
    return saved == true;
  }

  /// Shows the ask if this session end allows it. Returns whether it showed.
  Future<bool> maybeAsk(
    BuildContext context, {
    required int lessonsCompleted,
    required int streak,
  }) async {
    if (_showing || !_enabled()) return false;
    _showing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final asks = prefs.getInt(asksKey) ?? 0;
      final lastMs = prefs.getInt(lastAskKey);
      final now = _clock();
      final moment = SaveProgressPolicy.momentFor(
        lessonsCompleted: lessonsCompleted,
        streak: streak,
      );
      if (moment == null ||
          !SaveProgressPolicy.shouldAsk(
            needsAccount: _needsAccount(),
            canOffer: _canOffer(),
            asks: asks,
            lastAsk:
                lastMs == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(lastMs),
            now: now,
          )) {
        return false;
      }
      if (!context.mounted) return false;
      final answer = _present(context, moment);
      final ask = asks + 1;
      await prefs.setInt(asksKey, ask);
      await prefs.setInt(lastAskKey, now.millisecondsSinceEpoch);
      Analytics.track('save_progress_shown', {
        'moment': moment.name,
        'ask': ask,
        'lessons_completed': lessonsCompleted,
        'streak': streak,
      });
      final accepted = await answer == true;
      Analytics.track('save_progress_answered', {
        'moment': moment.name,
        'ask': ask,
        'choice': accepted ? 'save' : 'not_now',
      });
      if (accepted && context.mounted) {
        final saved = await _openAccount(context);
        Analytics.track('save_progress_result', {
          'moment': moment.name,
          'ask': ask,
          'saved': saved,
        });
        // Saved: never ask again.
        if (saved) await prefs.setInt(asksKey, SaveProgressPolicy.maxAsks);
      }
      return true;
    } catch (e) {
      debugPrint('Save progress ask skipped: $e');
      return false;
    } finally {
      _showing = false;
    }
  }

  static Future<bool?> _showSheet(
    BuildContext context,
    SaveProgressMoment moment,
  ) {
    final body = switch (moment) {
      SaveProgressMoment.firstLesson =>
        'Nice start! Create a free account so your words and streak stay '
            'safe if you change or lose your phone.',
      SaveProgressMoment.streak =>
        'Three days in a row! Create a free account so this streak is safe '
            'if you change or lose your phone.',
      SaveProgressMoment.later =>
        'Your progress lives only on this phone for now. A free account '
            'keeps it safe and lets you learn on another device.',
    };
    return showModalBottomSheet<bool>(
      context: context,
      routeSettings: const RouteSettings(name: 'save_progress'),
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
                        'Save your progress',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.display(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
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
                          key: const ValueKey('save_progress_save'),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save my progress'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        key: const ValueKey('save_progress_not_now'),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Not now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
