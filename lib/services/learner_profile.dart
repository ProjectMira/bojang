import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'api_service.dart';

/// The learner's public name and drawn avatar, for guests (anonymous
/// accounts) as much as for signed-in learners. Kept on the device so it
/// shows offline, and on the server (PATCH /auth/me) so the leaderboard and
/// a later sign-in carry it.
class LearnerProfile extends ChangeNotifier {
  LearnerProfile._();
  static final LearnerProfile instance = LearnerProfile._();

  static const String nameKey = 'learner_profile_name';
  static const String avatarKey = 'learner_profile_avatar';
  static const String askedKey = 'learner_profile_asked_at';
  static const String pendingKey = 'learner_profile_pending';

  /// How long "Later" keeps the setup sheet away.
  static const Duration askAgainAfter = Duration(days: 2);

  String? _name;
  String? _avatar;
  bool _loaded = false;

  String? get name => _name;
  String? get avatar => _avatar;
  bool get hasName => (_name ?? '').trim().isNotEmpty;
  bool get complete => hasName && _avatar != null;

  /// Replaced in tests.
  @visibleForTesting
  Future<Map<String, dynamic>?> Function() fetch =
      () => ApiService().getUserProfile();
  @visibleForTesting
  Future<Map<String, dynamic>?> Function(String name, String avatar) push =
      (name, avatar) =>
          ApiService().updateUserProfile(displayName: name, avatar: avatar);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = prefs.getString(nameKey);
      _avatar = prefs.getString(avatarKey);
      notifyListeners();
      // A save made offline goes up first.
      if (prefs.getBool(pendingKey) == true && complete) {
        unawaited(_upload());
        return;
      }
    } catch (_) {}
    unawaited(refresh());
  }

  /// Takes the server's name and avatar when this device has none.
  Future<void> refresh() async {
    try {
      final json = await fetch();
      if (json == null) return;
      final serverName = (json['display_name'] as String?)?.trim();
      final serverAvatar = json['avatar'] as String?;
      var changed = false;
      if (!hasName && serverName != null && serverName.isNotEmpty) {
        _name = serverName;
        changed = true;
      }
      if (_avatar == null && serverAvatar != null) {
        _avatar = serverAvatar;
        changed = true;
      }
      if (changed) {
        await _persist();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Learner profile fetch failed: $e');
    }
  }

  /// Saves on the device now, then on the server (retried at next launch).
  Future<void> save({required String name, required String avatar}) async {
    final clean = name.trim().split(RegExp(r'\s+')).join(' ');
    if (clean.isEmpty) return;
    _name = clean.length > 40 ? clean.substring(0, 40) : clean;
    _avatar = avatar;
    notifyListeners();
    await _persist(pending: true);
    Analytics.setPersonProperties({'name': _name, 'avatar': avatar});
    await _upload();
  }

  Future<void> _upload() async {
    final result = await push(_name!, _avatar!);
    if (result != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(pendingKey, false);
      } catch (_) {}
    }
  }

  Future<void> _persist({bool? pending}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_name != null) await prefs.setString(nameKey, _name!);
      if (_avatar != null) await prefs.setString(avatarKey, _avatar!);
      if (pending != null) await prefs.setBool(pendingKey, pending);
    } catch (_) {}
  }

  /// True when the setup sheet should open: something is missing and the
  /// learner has not said "Later" in the last [askAgainAfter].
  Future<bool> shouldAsk({DateTime? now}) async {
    await load();
    if (complete) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(askedKey);
      if (at == null) return true;
      final asked = DateTime.fromMillisecondsSinceEpoch(at);
      return (now ?? DateTime.now()).difference(asked) >= askAgainAfter;
    } catch (_) {
      return true;
    }
  }

  Future<void> markAsked({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        askedKey,
        (now ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Sign-out and account deletion: the next learner starts blank.
  Future<void> clear() async {
    _name = null;
    _avatar = null;
    _loaded = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in [nameKey, avatarKey, askedKey, pendingKey]) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  @visibleForTesting
  void debugReset() {
    _name = null;
    _avatar = null;
    _loaded = false;
    fetch = () => ApiService().getUserProfile();
    push =
        (name, avatar) =>
            ApiService().updateUserProfile(displayName: name, avatar: avatar);
  }
}
