import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_path.dart';
import 'api_service.dart';
import 'feature_flags.dart';

/// Loads the learning path and the review summary, keeping the last good
/// path on the device so Home still shows it offline.
class LearningPathRepository {
  LearningPathRepository._();

  /// Server flag (`/v1/config` flags). Off: Home shows the old topic list.
  static const String flag = 'learning_path_enabled';

  @visibleForTesting
  static const String cacheKey = 'learning_path_v1';

  /// Replaced in tests.
  static Future<Map<String, dynamic>?> Function() fetchPath =
      () => ApiService().getLearningPath();
  static Future<Map<String, dynamic>?> Function() fetchReview =
      () => ApiService().getReviewSummary();

  static bool get enabled =>
      FeatureFlags.instance.config.flagBool(flag, fallback: true);

  /// A fetch the splash started, so Home finds the path already on its way.
  static Future<LearningPath?>? _inFlight;

  /// Starts fetching the path now (splash, once sign-in is done). The next
  /// [load] picks the result up instead of starting its own request.
  static void prefetch() {
    _inFlight ??= _fetchFresh();
  }

  /// The path from the server, else the cached one, else null.
  static Future<LearningPath?> load() async {
    final pending = _inFlight;
    _inFlight = null;
    final fresh = await (pending ?? _fetchFresh());
    return fresh ?? cached();
  }

  static Future<LearningPath?> _fetchFresh() async {
    try {
      final json = await fetchPath();
      if (json != null && json['units'] is List) {
        final path = LearningPath.fromJson(json);
        if (path.units.isNotEmpty) {
          _store(json);
          return path;
        }
      }
    } catch (e) {
      debugPrint('Learning path fetch failed: $e');
    }
    return null;
  }

  static Future<LearningPath?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null) return null;
      final path = LearningPath.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return path.units.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _store(Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(json));
    } catch (_) {}
  }

  /// Null when offline or signed out.
  static Future<ReviewSummary?> loadReview() async {
    try {
      final json = await fetchReview();
      return json == null ? null : ReviewSummary.fromJson(json);
    } catch (e) {
      debugPrint('Review fetch failed: $e');
      return null;
    }
  }

  @visibleForTesting
  static void debugReset() {
    _inFlight = null;
    fetchPath = () => ApiService().getLearningPath();
    fetchReview = () => ApiService().getReviewSummary();
  }
}
