import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'api_service.dart';

/// What happened to a photo upload.
enum PhotoUploadResult { ok, tooLarge, notAPhoto, tooMany, offline, failed }

/// The learner's public name, drawn avatar and optional photo, for guests
/// (anonymous accounts) as much as for signed-in learners. The photo is tied
/// to the install's anonymous Firebase account: no email or login needed. Kept on the device so it
/// shows offline, and on the server (PATCH /auth/me) so the leaderboard and
/// a later sign-in carry it.
class LearnerProfile extends ChangeNotifier {
  LearnerProfile._();
  static final LearnerProfile instance = LearnerProfile._();

  static const String nameKey = 'learner_profile_name';
  static const String avatarKey = 'learner_profile_avatar';
  static const String askedKey = 'learner_profile_asked_at';
  static const String pendingKey = 'learner_profile_pending';
  static const String photoKey = 'learner_profile_photo';
  static const String defaultAvatarKey = 'learner_profile_default_avatar';

  /// How long "Later" keeps the setup sheet away.
  static const Duration askAgainAfter = Duration(days: 2);

  String? _name;
  String? _avatar;
  String? _photoUrl;
  bool _photoHidden = false;
  String? _defaultAvatar;
  bool _loaded = false;

  String? get name => _name;
  String? get avatar => _avatar;

  /// The uploaded photo (server URL), or null.
  String? get photoUrl => _photoUrl;

  /// True when reports have hidden the photo from others pending review.
  bool get photoHidden => _photoHidden;

  /// The drawn avatar to show: the learner's pick, else the server's stable
  /// default for them (so the profile header matches the board).
  String? get shownAvatar => _avatar ?? _defaultAvatar;
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
  @visibleForTesting
  Future<(int?, Map<String, dynamic>?)> Function(List<int> bytes, String name)
  uploader =
      (bytes, name) => ApiService().uploadProfilePhoto(bytes, filename: name);
  @visibleForTesting
  Future<bool> Function() remover = () => ApiService().deleteProfilePhoto();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = prefs.getString(nameKey);
      _avatar = prefs.getString(avatarKey);
      _photoUrl = prefs.getString(photoKey);
      _defaultAvatar = prefs.getString(defaultAvatarKey);
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
      // The server is the record for the photo (an admin may remove it).
      final serverPhoto = json['photo_url'] as String?;
      final hidden = json['photo_hidden'] == true;
      final fallback = json['default_avatar'] as String?;
      if (serverPhoto != _photoUrl ||
          hidden != _photoHidden ||
          (fallback != null && fallback != _defaultAvatar)) {
        _photoUrl = serverPhoto;
        _photoHidden = hidden;
        _defaultAvatar = fallback ?? _defaultAvatar;
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

  /// Uploads a photo picked from the library; on success it shows
  /// everywhere the learner's picture does.
  Future<PhotoUploadResult> uploadPhoto(
    List<int> bytes,
    String filename,
  ) async {
    if (bytes.length > 5 * 1024 * 1024) return PhotoUploadResult.tooLarge;
    final (status, body) = await uploader(bytes, filename);
    switch (status) {
      case null:
        return PhotoUploadResult.offline;
      case 200:
        final url = body?['photo_url'] as String?;
        if (url == null) return PhotoUploadResult.failed;
        _photoUrl = url;
        _photoHidden = body?['photo_hidden'] == true;
        notifyListeners();
        await _persist();
        return PhotoUploadResult.ok;
      case 413:
        return PhotoUploadResult.tooLarge;
      case 415:
      case 422:
        return PhotoUploadResult.notAPhoto;
      case 429:
        return PhotoUploadResult.tooMany;
      default:
        return PhotoUploadResult.failed;
    }
  }

  /// Removes the photo (the drawn avatar shows again). False when offline.
  Future<bool> removePhoto() async {
    if (!await remover()) return false;
    _photoUrl = null;
    _photoHidden = false;
    notifyListeners();
    await _persist();
    return true;
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
      if (_photoUrl != null) {
        await prefs.setString(photoKey, _photoUrl!);
      } else {
        await prefs.remove(photoKey);
      }
      if (_defaultAvatar != null) {
        await prefs.setString(defaultAvatarKey, _defaultAvatar!);
      }
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
    _photoUrl = null;
    _photoHidden = false;
    _defaultAvatar = null;
    _loaded = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in [
        nameKey,
        avatarKey,
        askedKey,
        pendingKey,
        photoKey,
        defaultAvatarKey,
      ]) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  @visibleForTesting
  void debugReset() {
    _name = null;
    _avatar = null;
    _photoUrl = null;
    _photoHidden = false;
    _defaultAvatar = null;
    _loaded = false;
    uploader =
        (bytes, name) => ApiService().uploadProfilePhoto(bytes, filename: name);
    remover = () => ApiService().deleteProfilePhoto();
    fetch = () => ApiService().getUserProfile();
    push =
        (name, avatar) =>
            ApiService().updateUserProfile(displayName: name, avatar: avatar);
  }
}
