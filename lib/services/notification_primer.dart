import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'progress_service.dart';
import 'push_service.dart';
import '../widgets/yak_mascot.dart';

/// The moment that just mattered, which the primer's copy refers to.
enum PrimerMoment { streak, freeze }

/// When the primer may be shown: at most [maxAsks] times in total, at least
/// [minGap] apart, and only while the OS prompt can still be shown.
class PrimerPolicy {
  PrimerPolicy._();

  static const int maxAsks = 3;
  static const Duration minGap = Duration(days: 3);

  static bool shouldAsk({
    required int asks,
    required DateTime? lastAsk,
    required DateTime now,
    required bool canPrompt,
  }) {
    if (!canPrompt || asks >= maxAsks) return false;
    if (lastAsk != null && now.difference(lastAsk) < minGap) return false;
    return true;
  }

  /// Whether the OS prompt can still change anything. iOS shows it only
  /// while undecided. Android 13+ reports "denied" until it is granted and
  /// shows the prompt again unless the learner refused it twice.
  static bool canPromptFor(AuthorizationStatus? status, TargetPlatform platform) {
    if (status == null) return false;
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      return false;
    }
    if (platform == TargetPlatform.iOS) {
      return status == AuthorizationStatus.notDetermined;
    }
    return true;
  }

  /// The celebration's moment: a freeze used, or the streak started or
  /// extended (the first practice of the day).
  static PrimerMoment? momentFor(StreakCelebration celebration) {
    if (celebration.freezesUsed > 0) return PrimerMoment.freeze;
    if (celebration.streak >= 1) return PrimerMoment.streak;
    return null;
  }
}

/// Asks for notification permission at a moment that matters, never at
/// launch: after the streak celebration of a lesson that starts or extends
/// the streak, or that used a freeze. A soft pre-prompt comes first ("Turn
/// on reminders" / "Maybe later"); only "Turn on" shows the OS prompt.
///
/// One call site: [StreakCelebrationScreen.maybeShow] calls
/// [afterStreakCelebration] once the celebration is closed.
class NotificationPrimer {
  NotificationPrimer({
    Future<bool> Function()? canPrompt,
    Future<bool> Function(String source)? requestPermission,
    Future<bool?> Function(BuildContext context, PrimerMoment moment)? present,
    DateTime Function()? clock,
  })  : _canPrompt = canPrompt ?? _osCanPrompt,
        _requestPermission = requestPermission ??
            ((source) => PushService.instance.requestPermission(source: source)),
        _present = present ?? _showPrePrompt,
        _clock = clock ?? DateTime.now;

  static NotificationPrimer instance = NotificationPrimer();

  static const asksKey = 'notification_primer_asks';
  static const lastAskKey = 'notification_primer_last_ask_ms';

  final Future<bool> Function() _canPrompt;
  final Future<bool> Function(String source) _requestPermission;
  final Future<bool?> Function(BuildContext context, PrimerMoment moment) _present;
  final DateTime Function() _clock;

  bool _showing = false;

  static Future<bool> _osCanPrompt() async {
    if (kIsWeb) return false;
    final status = await PushService.instance.permissionStatus();
    return PrimerPolicy.canPromptFor(status, defaultTargetPlatform);
  }

  /// Shows the pre-prompt if this celebration is a primer moment and the cap
  /// allows. Returns whether the pre-prompt was shown.
  Future<bool> afterStreakCelebration(
    BuildContext context,
    StreakCelebration celebration,
  ) async {
    final moment = PrimerPolicy.momentFor(celebration);
    if (moment == null) return false;
    return maybeAsk(context, moment);
  }

  /// Shows the pre-prompt for [moment] if allowed. Returns whether it was
  /// shown.
  Future<bool> maybeAsk(BuildContext context, PrimerMoment moment) async {
    if (_showing) return false;
    _showing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final asks = prefs.getInt(asksKey) ?? 0;
      final lastMs = prefs.getInt(lastAskKey);
      final now = _clock();
      final canPrompt = await _canPrompt();
      if (!PrimerPolicy.shouldAsk(
        asks: asks,
        lastAsk: lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs),
        now: now,
        canPrompt: canPrompt,
      )) {
        return false;
      }
      if (!context.mounted) return false;

      final answer = _present(context, moment);
      // Counted when shown, so a dismissed sheet still uses up one ask.
      final ask = asks + 1;
      Analytics.track('notification_primer_shown', {
        'moment': moment.name,
        'ask': ask,
      });
      await prefs.setInt(asksKey, ask);
      await prefs.setInt(lastAskKey, now.millisecondsSinceEpoch);

      final accepted = await answer == true;
      Analytics.track('notification_primer_answered', {
        'moment': moment.name,
        'ask': ask,
        'choice': accepted ? 'turn_on' : 'maybe_later',
      });
      if (accepted) {
        final allowed = await _requestPermission('primer_${moment.name}');
        // Allowed or refused at the OS level: either way, stop asking.
        if (!allowed) await prefs.setInt(asksKey, PrimerPolicy.maxAsks);
      }
      return true;
    } catch (e) {
      debugPrint('Notification primer skipped: $e');
      return false;
    } finally {
      _showing = false;
    }
  }

  static Future<bool?> _showPrePrompt(BuildContext context, PrimerMoment moment) {
    final title = moment == PrimerMoment.freeze
        ? 'Want a heads-up next time?'
        : 'Want a nudge from Norbu?';
    final body = moment == PrimerMoment.freeze
        ? 'A freeze kept your streak safe. Norbu can send one friendly '
            'reminder on evenings you haven\'t practised yet, so your freezes '
            'can stay in reserve.'
        : 'Your streak is under way! Norbu can send one friendly reminder on '
            'evenings you haven\'t practised yet. Never after midnight, and '
            'you can turn it off any time in Settings.';
    return showModalBottomSheet<bool>(
      context: context,
      routeSettings: const RouteSettings(name: 'notification_primer'),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const YakMascot(mood: YakMood.waving, size: 96),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Turn on reminders'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Maybe later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
