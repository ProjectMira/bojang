import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';

/// The learner's approximate location, shared only with permission, for
/// analytics (which regions learners are in).
///
/// - iOS gives approximate location only (NSLocationDefaultAccuracyReduced);
///   Android asks for coarse location only.
/// - Coordinates are rounded to 0.1 degree (about 10 km) before they leave
///   the phone, and sent with the country, region and city names.
/// - Asked once, after the first finished lesson, with an explanation first
///   ([maybePromptAfterLesson]); Settings > Privacy has a switch.
/// - Nothing is sent while "Share usage analytics" is off.
/// - Refreshed at most once a day ([refreshIfAllowed], on app start).
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _promptedKey = 'location_prompted';
  static const _enabledKey = 'location_sharing';
  static const _lastSentKey = 'location_last_sent';

  /// Whether the learner switched location sharing on in the app.
  Future<bool> get sharingEnabled async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the explanation once, after the learner's first finished lesson.
  Future<void> maybePromptAfterLesson(BuildContext context) async {
    if (kIsWeb || Analytics.optedOut) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_promptedKey) ?? false) return;
      await prefs.setBool(_promptedKey, true);
      if (!context.mounted) return;
      Analytics.track('location_prompt_shown', {'source': 'lesson_complete'});
      final share = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Where are you learning from?'),
          content: const Text(
            'Share your approximate location (about 10 km, never your exact '
            'position) so we can see which regions Bojang learners are in and '
            'plan lessons, dialects and voices for them. You can turn this off '
            'any time in Settings › Privacy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Share location'),
            ),
          ],
        ),
      );
      Analytics.track('location_prompt_answered', {'share': share == true});
      if (share == true) await setSharing(true, source: 'lesson_complete');
    } catch (e) {
      debugPrint('Location prompt failed: $e');
    }
  }

  /// Turns sharing on (asks for permission, sends the location) or off.
  /// Returns whether sharing is on afterwards.
  Future<bool> setSharing(bool on, {required String source}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!on) {
      await prefs.setBool(_enabledKey, false);
      Analytics.track('location_sharing_changed', {'enabled': false, 'source': source});
      return false;
    }
    final permission = await _ensurePermission();
    final granted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    await prefs.setBool(_enabledKey, granted);
    Analytics.track('location_sharing_changed', {
      'enabled': granted,
      'permission': permission.name,
      'source': source,
    });
    if (granted) await _send(force: true);
    return granted;
  }

  /// On app start: sends a fresh location at most once a day, only if the
  /// learner turned sharing on and the permission is still granted.
  Future<void> refreshIfAllowed() async {
    if (kIsWeb || Analytics.optedOut) return;
    try {
      if (!await sharingEnabled) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      await _send(force: false);
    } catch (e) {
      debugPrint('Location refresh failed: $e');
    }
  }

  Future<LocationPermission> _ensurePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission;
    } catch (e) {
      debugPrint('Location permission failed: $e');
      return LocationPermission.denied;
    }
  }

  Future<void> _send({required bool force}) async {
    if (Analytics.optedOut) return;
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.tryParse(prefs.getString(_lastSentKey) ?? '');
    if (!force && last != null && DateTime.now().difference(last) < const Duration(days: 1)) {
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      Analytics.track('location_unavailable', {'reason': 'services_off'});
      return;
    }
    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      Analytics.track('location_unavailable', {'reason': e.runtimeType.toString()});
      return;
    }

    final place = await _placeFor(position.latitude, position.longitude);
    final properties = <String, Object?>{
      'approx_lat': roundCoordinate(position.latitude),
      'approx_lon': roundCoordinate(position.longitude),
      'accuracy_km': (position.accuracy / 1000).round(),
      ...place,
    };
    Analytics.track('location_shared', properties);
    Analytics.setPersonProperties({
      'location_country': place['country'],
      'location_country_code': place['country_code'],
      'location_region': place['region'],
      'location_city': place['city'],
      'location_approx_lat': properties['approx_lat'],
      'location_approx_lon': properties['approx_lon'],
    });
    await prefs.setString(_lastSentKey, DateTime.now().toIso8601String());
  }

  Future<Map<String, Object?>> _placeFor(double lat, double lon) async {
    try {
      // English place names, whatever the phone's language.
      final places = await Geocoding(locale: const Locale('en'))
          .placemarkFromCoordinates(roundCoordinate(lat), roundCoordinate(lon))
          .timeout(const Duration(seconds: 8));
      if (places.isEmpty) return const {};
      final p = places.first;
      String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
      return {
        'country': clean(p.country),
        'country_code': clean(p.isoCountryCode),
        'region': clean(p.administrativeArea),
        'city': clean(p.locality) ?? clean(p.subAdministrativeArea),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Rounds to 0.1 degree, about 10 km.
  @visibleForTesting
  static double roundCoordinate(double value) => (value * 10).round() / 10;
}
