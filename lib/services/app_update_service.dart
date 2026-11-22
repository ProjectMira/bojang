import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';
import 'app_config.dart';
import 'feature_flags.dart';

/// The newest release of the app in the App Store, as the iTunes lookup API
/// reports it.
class StoreRelease {
  const StoreRelease({
    required this.version,
    required this.appStoreId,
    this.minimumOsVersion,
  });

  /// Marketing version, e.g. "2.7.0".
  final String version;

  /// The app's numeric App Store id (`trackId`).
  final int appStoreId;

  /// Oldest iOS the release installs on, e.g. "15.0".
  final String? minimumOsVersion;

  static StoreRelease? fromLookup(Map<String, dynamic> json) {
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;
    final app = results.first;
    if (app is! Map) return null;
    final version = app['version'];
    final trackId = app['trackId'];
    if (version is! String || trackId is! int) return null;
    final minOs = app['minimumOsVersion'];
    return StoreRelease(
      version: version,
      appStoreId: trackId,
      minimumOsVersion: minOs is String ? minOs : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'app_store_id': appStoreId,
    'minimum_os_version': minimumOsVersion,
  };

  static StoreRelease? fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final id = json['app_store_id'];
    if (version is! String || id is! int) return null;
    final minOs = json['minimum_os_version'];
    return StoreRelease(
      version: version,
      appStoreId: id,
      minimumOsVersion: minOs is String ? minOs : null,
    );
  }
}

/// Why the update wall is up.
enum UpdateReason {
  /// The App Store has a newer version than the one installed (iOS).
  storeRelease,

  /// The build is below the server's `min_supported_build` (any platform).
  belowMinimumBuild,
}

/// A store release newer than the installed app. The learner has to install
/// it before they can keep using the app.
class RequiredUpdate {
  const RequiredUpdate({
    required this.installedVersion,
    this.storeVersion = '',
    this.appStoreId,
    this.packageName,
    this.storeUrl,
    this.title,
    this.message,
    this.reason = UpdateReason.storeRelease,
  });

  final String installedVersion;

  /// The store's version when known (the App Store lookup); empty when the
  /// wall comes from the server minimum alone.
  final String storeVersion;

  /// App Store id (iOS); null on Android.
  final int? appStoreId;

  /// Android application id, for the Play Store links.
  final String? packageName;

  /// https store page from the server config, tried last.
  final String? storeUrl;

  /// Server copy for the wall; null keeps the screen's own words.
  final String? title;
  final String? message;

  final UpdateReason reason;

  bool get isAndroid => appStoreId == null && packageName != null;

  /// "App Store" or "Play Store", for the wall's copy.
  String get storeName => isAndroid ? 'Play Store' : 'App Store';

  /// Opens the product page straight in the App Store app.
  Uri get appStoreUri =>
      Uri.parse('itms-apps://apps.apple.com/app/id$appStoreId');

  /// Same page on the web, for when the App Store app is missing (the
  /// simulator) or will not open. On a device iOS hands it to the App Store.
  Uri get webUri => Uri.parse('https://apps.apple.com/app/id$appStoreId');

  /// Links to try in order: the store app first, then the web page.
  List<Uri> get storeUris => [
    if (appStoreId != null) ...[appStoreUri, webUri],
    if (isAndroid) ...[
      Uri.parse('market://details?id=$packageName'),
      Uri.parse('https://play.google.com/store/apps/details?id=$packageName'),
    ],
    if (storeUrl != null) Uri.parse(storeUrl!),
  ];
}

/// Decides whether the installed app must be updated before it can be used.
///
/// Two sources, either one raises the wall:
/// - the server config's `min_supported_build` for this platform (iOS and
///   Android), from [FeatureFlags]: cached across launches, so going
///   offline does not get around it;
/// - iOS only: the App Store has a newer version than the one installed
///   (the Play Store has no public lookup).
///
/// Both fail open: no answer and nothing cached means no wall.
class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Future<PackageInfo> Function()? packageInfo,
    String Function()? osVersion,
    bool? isIOS,
    bool? isAndroid,
    Future<ServerConfig?> Function()? serverConfig,
  }) : _client = client ?? http.Client(),
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _osVersion = osVersion ?? (() => Platform.operatingSystemVersion),
       _isIOS = isIOS ?? AppConfig.isIOS,
       _isAndroid =
           isAndroid ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
       _serverConfig = serverConfig ?? _latestServerConfig;

  final http.Client _client;
  final Future<PackageInfo> Function() _packageInfo;
  final String Function() _osVersion;
  final bool _isIOS;
  final bool _isAndroid;
  final Future<ServerConfig?> Function() _serverConfig;

  static Future<ServerConfig?> _latestServerConfig() async {
    final flags = FeatureFlags.instance;
    unawaited(flags.refresh());
    return flags.latest();
  }

  /// `ios`, `android`, or null where there is no wall.
  String? get _platform => _isIOS ? 'ios' : (_isAndroid ? 'android' : null);

  static const Duration lookupTimeout = Duration(seconds: 8);

  /// The last release the store reported, so going offline does not get
  /// around an update the app already knows about.
  @visibleForTesting
  static const String cacheKey = 'app_store_release';

  /// Returns the update the learner must install, or null when the app is up
  /// to date. When the store cannot be reached the last release it reported
  /// is used; with none on record the app is let through, so a failed check
  /// never locks anyone out. A release that needs a newer iOS than the device
  /// runs is ignored, because the App Store would not offer it.
  Future<RequiredUpdate?> check() async {
    final platform = _platform;
    if (platform == null) return null;
    try {
      final info = await _packageInfo();
      final belowMinimum = await _serverMinimum(info, platform);
      if (belowMinimum != null) return belowMinimum;
      if (!_isIOS) return null;
      final release = await _currentRelease(info.packageName);
      if (release == null) return null;
      return _evaluate(info.version, release);
    } catch (e) {
      debugPrint('App update check skipped: $e');
      return null;
    }
  }

  /// The wall from the server's `min_supported_build`, or null. A failure
  /// here never blocks (fail open).
  Future<RequiredUpdate?> _serverMinimum(
    PackageInfo info,
    String platform,
  ) async {
    final ServerConfig? config;
    try {
      config = await _serverConfig();
    } catch (e) {
      debugPrint('Server minimum build check skipped: $e');
      return null;
    }
    if (config == null ||
        !config.requiresUpdate(
          platform: platform,
          installedBuild: info.buildNumber,
        )) {
      return null;
    }
    int? appStoreId;
    if (_isIOS) {
      try {
        appStoreId =
            _cachedRelease(await SharedPreferences.getInstance())?.appStoreId;
      } catch (_) {}
    }
    return RequiredUpdate(
      installedVersion: info.version,
      appStoreId: appStoreId,
      packageName: _isIOS ? null : info.packageName,
      storeUrl: config.storeUrls[platform],
      title: config.updateTitle,
      message: config.updateMessage,
      reason: UpdateReason.belowMinimumBuild,
    );
  }

  Future<StoreRelease?> _currentRelease(String bundleId) async {
    final prefs = await SharedPreferences.getInstance();
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https('itunes.apple.com', '/lookup', {
              'bundleId': bundleId,
              // The lookup sits behind a CDN that can serve an answer from
              // before the latest release for hours.
              '_cb': DateTime.now().millisecondsSinceEpoch.toString(),
            }),
          )
          .timeout(lookupTimeout);
    } catch (e) {
      debugPrint('App Store lookup failed: $e');
      return _cachedRelease(prefs);
    }
    if (response.statusCode != 200) return _cachedRelease(prefs);

    final StoreRelease? release;
    try {
      release = StoreRelease.fromLookup(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      return _cachedRelease(prefs);
    }
    if (release == null) {
      // The store answered but no longer lists the app: nothing to update to.
      await prefs.remove(cacheKey);
      return null;
    }
    await prefs.setString(cacheKey, jsonEncode(release.toJson()));
    return release;
  }

  StoreRelease? _cachedRelease(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      return StoreRelease.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  RequiredUpdate? _evaluate(String installed, StoreRelease release) {
    if (!isVersion(installed) || !isVersion(release.version)) return null;
    if (compareVersions(release.version, installed) <= 0) return null;

    final minOs = release.minimumOsVersion;
    if (minOs != null && isVersion(minOs)) {
      final deviceOs = parseOsVersion(_osVersion());
      if (deviceOs == null || compareVersions(deviceOs, minOs) < 0) {
        return null;
      }
    }
    return RequiredUpdate(
      installedVersion: installed,
      storeVersion: release.version,
      appStoreId: release.appStoreId,
    );
  }

  static final RegExp _versionPattern = RegExp(r'^\d+(\.\d+)*$');

  /// True for dotted numeric versions such as "2", "2.6" and "2.6.1".
  static bool isVersion(String value) => _versionPattern.hasMatch(value.trim());

  /// Compares dotted numeric versions part by part, so "2.10.0" is newer
  /// than "2.9.3". Missing parts count as zero ("2.6" equals "2.6.0").
  static int compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.trim().split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final x = parts(a);
    final y = parts(b);
    for (var i = 0; i < math.max(x.length, y.length); i++) {
      final diff = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
      if (diff != 0) return diff;
    }
    return 0;
  }

  /// Pulls "17.2" out of iOS's "Version 17.2 (Build 21C62)".
  static String? parseOsVersion(String raw) =>
      RegExp(r'\d+(\.\d+)+').firstMatch(raw)?.group(0);
}
