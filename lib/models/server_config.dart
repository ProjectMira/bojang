/// The app config served by the backend's `GET /v1/config` (plan item #20).
///
/// Owned by the server: the update wall for every platform, per-feature kill
/// switches, the analytics blocklist and sampling map, server-owned flags
/// and the reward values the server grants with. Copy and UI tweaks stay in
/// Firebase Remote Config (`RemoteSettings`).
///
/// Parsing is forgiving: a missing or malformed field falls back to the
/// fail-open default (no wall, nothing switched off, everything sent), so a
/// bad payload can never lock learners out.
class ServerConfig {
  const ServerConfig({
    this.minSupportedBuild = const {},
    this.updateTitle,
    this.updateMessage,
    this.storeUrls = const {},
    this.killSwitches = const {},
    this.eventBlocklist = const {},
    this.eventSampling = const {},
    this.flags = const {},
    this.rewards = const {},
  });

  /// Nothing known yet: no wall, every feature on, every event sent.
  static const ServerConfig failOpen = ServerConfig();

  /// Platform (`ios`, `android`) -> lowest build number still allowed in.
  final Map<String, int> minSupportedBuild;

  /// Copy for the update wall; null keeps the app's own words.
  final String? updateTitle;
  final String? updateMessage;

  /// Platform -> https store page, used when the native store link fails.
  final Map<String, String> storeUrls;

  /// Feature -> true when the server switched it off.
  final Map<String, bool> killSwitches;

  final Set<String> eventBlocklist;

  /// Event -> share of app sessions that send it (0.0 to 1.0).
  final Map<String, double> eventSampling;

  /// Server-owned flags: bool, number or string.
  final Map<String, Object> flags;

  /// What the server grants (`xp_per_correct_answer`, ...). For display only.
  final Map<String, int> rewards;

  static ServerConfig fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) {
      final value = json[key];
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    }

    final update = section('update');
    final analytics = section('analytics');
    return ServerConfig(
      minSupportedBuild: {
        for (final e in section('min_supported_build').entries)
          if (e.value is int && (e.value as int) > 0) e.key: e.value as int,
      },
      updateTitle: _text(update['title']),
      updateMessage: _text(update['message']),
      storeUrls: {
        if (update['store_url'] is Map)
          for (final e in (update['store_url'] as Map).entries)
            if (e.value is String && (e.value as String).startsWith('https://'))
              e.key.toString(): e.value as String,
      },
      killSwitches: {
        for (final e in section('kill_switches').entries)
          if (e.value is bool) e.key: e.value as bool,
      },
      eventBlocklist: {
        if (analytics['blocklist'] is List)
          for (final name in analytics['blocklist'] as List)
            if (name is String) name,
      },
      eventSampling: {
        if (analytics['sampling'] is Map)
          for (final e in (analytics['sampling'] as Map).entries)
            if (e.value is num)
              e.key.toString(): (e.value as num).toDouble().clamp(0.0, 1.0),
      },
      flags: {
        for (final e in section('flags').entries)
          if (e.value is bool || e.value is num || e.value is String)
            e.key: e.value as Object,
      },
      rewards: {
        for (final e in section('rewards').entries)
          if (e.value is int) e.key: e.value as int,
      },
    );
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  /// False only when the server switched [feature] off. Unknown features
  /// are on.
  bool isEnabled(String feature) => killSwitches[feature] != true;

  bool flagBool(String name, {bool fallback = false}) {
    final value = flags[name];
    return value is bool ? value : fallback;
  }

  num flagNum(String name, {num fallback = 0}) {
    final value = flags[name];
    return value is num ? value : fallback;
  }

  String flagString(String name, {String fallback = ''}) {
    final value = flags[name];
    return value is String ? value : fallback;
  }

  /// True when the installed build is older than this platform's minimum.
  bool requiresUpdate({
    required String? platform,
    required String installedBuild,
  }) {
    if (platform == null) return false;
    return isBelowMinimumBuild(installedBuild, minSupportedBuild[platform]);
  }

  /// Compares the installed build number (CFBundleVersion / versionCode, as
  /// `PackageInfo.buildNumber` reports it) with a minimum. Fails open: no
  /// minimum, a minimum of 0, or a build number that is not a whole number
  /// never blocks.
  static bool isBelowMinimumBuild(String installedBuild, int? minimum) {
    if (minimum == null || minimum <= 0) return false;
    final build = parseBuildNumber(installedBuild);
    if (build == null) return false;
    return build < minimum;
  }

  /// "63" -> 63. Tolerates surrounding spaces; anything else is null.
  static int? parseBuildNumber(String raw) {
    final trimmed = raw.trim();
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) return null;
    return int.tryParse(trimmed);
  }
}
