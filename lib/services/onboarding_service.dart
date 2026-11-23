import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding.dart';
import 'feature_flags.dart';
import 'user_kv.dart';

/// Stores onboarding state on the device and the answers in user_kv
/// (namespace `onboarding`, see [OnboardingKeys]).
///
/// Answers are kept on the device first and sent to the server after, so
/// an answer given offline, or before the anonymous account exists, is not
/// lost: whatever has not reached the server yet is sent again on the next
/// launch ([syncPending]).
class OnboardingService {
  OnboardingService({OnboardingAnswers? answers, bool Function()? enabled})
    : _answers = answers ?? OnboardingAnswers(),
      _enabled = enabled ?? (() => FeatureFlags.instance.isEnabled(killSwitch));

  static OnboardingService instance = OnboardingService();

  /// The `/v1/config` kill switch.
  static const String killSwitch = 'onboarding';

  static const String statusKey = 'onboarding_status';
  static const String pendingKey = 'onboarding_pending_answers';

  /// Every answer, also on the device so the app can read them offline.
  static const String answersKey = 'onboarding_answers';

  /// The step a learner who left mid-way was on, for analytics.
  static const String lastStepKey = 'onboarding_last_step';

  final OnboardingAnswers _answers;
  final bool Function() _enabled;

  bool get enabled => _enabled();

  Future<OnboardingStatus?> status() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingStatus.fromId(prefs.getString(statusKey));
  }

  Future<void> setStatus(OnboardingStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(statusKey, status.name);
  }

  /// Decides whether this launch opens onboarding. A first decision is
  /// stored: an install found in use ([OnboardingGate.isExistingInstall]) is
  /// marked [OnboardingStatus.existing] for good. [storedKeys] are the
  /// device storage keys as they were before this launch wrote any.
  Future<bool> shouldShow({
    required Set<String> storedKeys,
    required bool hadAccount,
  }) async {
    try {
      final current = await status();
      final existing =
          current == null &&
          OnboardingGate.isExistingInstall(
            storedKeys: storedKeys,
            hadAccount: hadAccount,
          );
      if (existing) await setStatus(OnboardingStatus.existing);
      return OnboardingGate.shouldShow(
        enabled: enabled,
        status: existing ? OnboardingStatus.existing : current,
        existingInstall: existing,
      );
    } catch (e) {
      debugPrint('Onboarding check skipped: $e');
      return false;
    }
  }

  /// The answers given on this device (see [OnboardingKeys]).
  Future<Map<String, Object?>> localAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(answersKey));
  }

  /// The level the path starts at, from the device (null before onboarding
  /// or for installs that never saw it).
  Future<String?> startLevelId() async {
    final level = (await localAnswers())[OnboardingKeys.startLevel];
    return level is String ? level : null;
  }

  /// Keeps [value] for [key] on the device and queues it for the server.
  Future<void> remember(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    final all = _decode(prefs.getString(answersKey))..[key] = value;
    final pending = _decode(prefs.getString(pendingKey))..[key] = value;
    await prefs.setString(answersKey, jsonEncode(all));
    await prefs.setString(pendingKey, jsonEncode(pending));
  }

  Future<String?> lastStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(lastStepKey);
  }

  Future<void> setLastStep(String step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastStepKey, step);
  }

  /// Sends the queued answers to user_kv. Returns true when nothing is left
  /// to send. Never throws.
  Future<bool> syncPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = _decode(prefs.getString(pendingKey));
      if (pending.isEmpty) return true;
      final sent = <String>[];
      for (final entry in pending.entries) {
        if (await _answers.save(entry.key, entry.value as Object)) {
          sent.add(entry.key);
        }
      }
      // Re-read: an answer given while sending must not be dropped.
      final latest = _decode(prefs.getString(pendingKey));
      for (final key in sent) {
        if (jsonEncode(latest[key]) == jsonEncode(pending[key])) {
          latest.remove(key);
        }
      }
      if (latest.isEmpty) {
        await prefs.remove(pendingKey);
      } else {
        await prefs.setString(pendingKey, jsonEncode(latest));
      }
      return latest.isEmpty;
    } catch (e) {
      debugPrint('Onboarding answers not synced: $e');
      return false;
    }
  }

  static Map<String, Object?> _decode(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {}
    return {};
  }
}
