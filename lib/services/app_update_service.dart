import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

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

/// A store release newer than the installed app. The learner has to install
/// it before they can keep using the app.
class RequiredUpdate {
  const RequiredUpdate({
    required this.installedVersion,
    required this.storeVersion,
    required this.appStoreId,
  });

  final String installedVersion;
  final String storeVersion;
  final int appStoreId;

  /// Opens the product page straight in the App Store app.
  Uri get appStoreUri =>
      Uri.parse('itms-apps://apps.apple.com/app/id$appStoreId');

  /// Same page on the web, for when the App Store app is missing (the
  /// simulator) or will not open. On a device iOS hands it to the App Store.
  Uri get webUri => Uri.parse('https://apps.apple.com/app/id$appStoreId');
}

/// Decides whether the installed app is older than the App Store release.
///
/// iOS only: the Play Store has no public lookup, so elsewhere [check] always
/// answers "no update needed".
class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    Future<PackageInfo> Function()? packageInfo,
    String Function()? osVersion,
    bool? isIOS,
  }) : _client = client ?? http.Client(),
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _osVersion = osVersion ?? (() => Platform.operatingSystemVersion),
       _isIOS = isIOS ?? AppConfig.isIOS;

  final http.Client _client;
  final Future<PackageInfo> Function() _packageInfo;
  final String Function() _osVersion;
  final bool _isIOS;

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
    if (!_isIOS) return null;
    try {
      final info = await _packageInfo();
      final release = await _currentRelease(info.packageName);
      if (release == null) return null;
      return _evaluate(info.version, release);
    } catch (e) {
      debugPrint('App update check skipped: $e');
      return null;
    }
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
