import 'package:shared_preferences/shared_preferences.dart';

import '../models/social.dart';
import 'api_service.dart';
import 'feature_flags.dart';

/// The app side of the weekly leaderboard (plan #24) and family streaks
/// (#26). Screens call this, not [ApiService], so the kill switches and the
/// small bits of local state live in one place.
class SocialService {
  SocialService({ApiService? api}) : _api = api ?? ApiService();

  static final SocialService instance = SocialService();

  final ApiService _api;

  static const String visibleKey = 'leaderboard_visible';
  static const String resultShownKey = 'leaderboard_result_shown_week';

  static bool get leaderboardEnabled =>
      FeatureFlags.instance.isEnabled('leaderboard');

  /// `family` kill switch; on unless the server turns it off.
  static bool get familyEnabled => FeatureFlags.instance.isEnabled('family');

  // ── Leaderboard ────────────────────────────────────────────────────

  Future<WeeklyBoard?> weeklyBoard() async {
    final board = WeeklyBoard.fromJson(await _api.getWeeklyLeaderboard());
    if (board != null) await _rememberVisible(board.me.visible);
    return board;
  }

  /// Last-known "Show me on the leaderboard" (default on).
  Future<bool> visible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(visibleKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Saves the choice on the server; keeps it locally only when it stuck.
  Future<bool> setVisible(bool visible) async {
    final ok = await _api.setLeaderboardVisible(visible);
    if (ok) await _rememberVisible(visible);
    return ok;
  }

  Future<void> _rememberVisible(bool visible) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(visibleKey, visible);
    } catch (_) {}
  }

  /// Last week's result if it has not been shown yet ("You finished #12").
  /// Marks it shown, so it appears once per week.
  Future<WeeklyResult?> unseenLastWeekResult() async {
    if (!leaderboardEnabled) return null;
    final result = WeeklyResult.fromJson(await _api.getLastWeekResult());
    if (result == null) return null;
    final prefs = await SharedPreferences.getInstance();
    if (!result.shouldShow(prefs.getString(resultShownKey))) return null;
    await prefs.setString(resultShownKey, result.weekKey);
    return result;
  }

  // ── Family ─────────────────────────────────────────────────────────

  Future<FamilyState?> family() async =>
      FamilyState.fromJson(await _api.getFamily());

  Future<FamilyInvite?> createInvite() async =>
      FamilyInvite.fromJson(await _api.createFamilyInvite());

  /// Null on success, otherwise why it failed.
  Future<InviteError?> acceptInvite(String typed) async {
    final code = normalizeInviteCode(typed);
    if (code == null) return InviteError.invalid;
    final (status, body) = await _api.acceptFamilyInvite(code);
    if (status != null && status >= 200 && status < 300) return null;
    return inviteErrorFrom(status, body is Map ? body['detail'] : null);
  }

  Future<bool> remove(String linkId) => _api.removeFamilyLink(linkId);

  /// The push went out (true), or why not.
  Future<NudgeOutcome> nudge(String linkId) async {
    final (status, _) = await _api.nudgeFamilyMember(linkId);
    return switch (status) {
      null => NudgeOutcome.offline,
      200 => NudgeOutcome.sent,
      409 => NudgeOutcome.alreadyPractised,
      429 => NudgeOutcome.alreadyNudged,
      _ => NudgeOutcome.failed,
    };
  }
}

enum NudgeOutcome { sent, alreadyNudged, alreadyPractised, offline, failed }

/// The message shared with an invite code. The app has no deep links, so
/// the other person types the code in Profile > Family.
String familyInviteMessage(String code) =>
    'Learn Tibetan with me on Bojang and we can keep a family streak '
    'together. Get the app at https://www.bojang.in, then open Profile > '
    'Family and enter my code: $code';
