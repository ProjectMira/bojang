import 'dart:convert';

/// Fits Bojang's analytics events to Google Analytics for Firebase's limits,
/// so the Firebase mirror in `Analytics` never sends something GA4 drops or
/// the SDK rejects.
///
/// GA4 limits: event names up to 40 characters of [a-zA-Z0-9_] starting with
/// a letter, not reserved and without the `firebase_` / `google_` / `ga_`
/// prefixes; up to 25 parameters per event, names up to 40 characters,
/// string values up to 100; user property names up to 24 characters, values
/// up to 36. Values may only be strings or numbers.
///
/// No PII goes to Google: names, emails, avatars and coordinates are left
/// out (Google Analytics terms forbid PII, and coordinates would add a
/// location data type to the App Store label for Google).
class FirebaseEventRules {
  FirebaseEventRules._();

  static const int maxEventName = 40;
  static const int maxParams = 25;
  static const int maxParamName = 40;
  static const int maxParamValue = 100;
  static const int maxUserPropertyName = 24;
  static const int maxUserPropertyValue = 36;

  /// Event names GA4 reserves for its own automatic events.
  static const Set<String> reservedEvents = {
    'ad_activeview',
    'ad_click',
    'ad_exposure',
    'ad_impression',
    'ad_query',
    'ad_reward',
    'adunit_exposure',
    'app_background',
    'app_clear_data',
    'app_exception',
    'app_remove',
    'app_store_refund',
    'app_store_subscription_cancel',
    'app_store_subscription_convert',
    'app_store_subscription_renew',
    'app_update',
    'app_upgrade',
    'dynamic_link_app_open',
    'dynamic_link_app_update',
    'dynamic_link_first_open',
    'error',
    'first_open',
    'first_visit',
    'in_app_purchase',
    'notification_dismiss',
    'notification_foreground',
    'notification_open',
    'notification_receive',
    'os_update',
    'screen_view',
    'session_start',
    'session_start_with_rollout',
    'user_engagement',
  };

  /// User property names GA4 reserves.
  static const Set<String> reservedUserProperties = {
    'age',
    'first_open_after_install',
    'first_open_time',
    'first_visit_time',
    'gender',
    'interests',
    'last_deep_link_referrer',
    'user_id',
  };

  static const List<String> _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

  /// Keys never sent to Google (PII and coordinates).
  static const Set<String> blockedKeys = {
    'name',
    'display_name',
    'first_name',
    'last_name',
    'avatar',
    'photo_url',
    'phone',
    'approx_lat',
    'approx_lon',
    'location_approx_lat',
    'location_approx_lon',
    'lat',
    'lon',
    'latitude',
    'longitude',
    'location_city',
  };

  static bool isBlockedKey(String key) =>
      blockedKeys.contains(key) || key.contains('email');

  static final RegExp _invalid = RegExp('[^a-zA-Z0-9_]');

  /// Letters, digits and underscores only, starting with a letter, no
  /// reserved prefix, at most [max] characters. Null when nothing is left.
  static String? _clean(String raw, int max) {
    var s = raw.replaceAll(_invalid, '_');
    while (s.isNotEmpty && !_isLetter(s.codeUnitAt(0))) {
      s = s.substring(1);
    }
    if (s.isEmpty) return null;
    for (final prefix in _reservedPrefixes) {
      if (s.toLowerCase().startsWith(prefix)) {
        s = 'bj_$s';
        break;
      }
    }
    return s.length > max ? s.substring(0, max) : s;
  }

  static bool _isLetter(int c) =>
      (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);

  /// The GA4 name for [event], or null for events that are not mirrored
  /// (PostHog `$` events: `$screen` goes through logScreenView instead).
  static String? eventName(String event) {
    if (event.startsWith(r'$')) return null;
    final name = _clean(event, maxEventName);
    if (name == null) return null;
    if (reservedEvents.contains(name)) {
      return _clean('bj_$name', maxEventName);
    }
    return name;
  }

  /// Parameters for one event: nulls and blocked keys dropped, booleans as
  /// 0/1, numbers kept, everything else a string of at most 100 characters,
  /// at most 25 entries (in the order given).
  static Map<String, Object> params(Map<String, Object?> properties) {
    final out = <String, Object>{};
    for (final e in properties.entries) {
      if (out.length >= maxParams) break;
      final value = e.value;
      if (value == null || isBlockedKey(e.key)) continue;
      final key = _clean(e.key, maxParamName);
      if (key == null || out.containsKey(key)) continue;
      out[key] = _value(value, maxParamValue);
    }
    return out;
  }

  static Object _value(Object value, int max) {
    if (value is bool) return value ? 1 : 0;
    if (value is int || value is double) {
      final n = value as num;
      return n.isFinite ? n : n.toString();
    }
    String s;
    if (value is String) {
      s = value;
    } else if (value is Map || value is Iterable) {
      try {
        s = jsonEncode(value);
      } catch (_) {
        s = value.toString();
      }
    } else {
      s = value.toString();
    }
    return s.length > max ? s.substring(0, max) : s;
  }

  /// User properties for GA4: name -> value as a string of at most 36
  /// characters (null clears it). Names longer than 24 characters, reserved
  /// or blocked ones are left out rather than cut, so two never collide.
  static Map<String, String?> userProperties(Map<String, Object?> properties) {
    final out = <String, String?>{};
    for (final e in properties.entries) {
      if (isBlockedKey(e.key)) continue;
      final key = _clean(e.key, 1 << 10);
      if (key == null ||
          key.length > maxUserPropertyName ||
          reservedUserProperties.contains(key)) {
        continue;
      }
      final value = e.value;
      if (value == null) {
        out[key] = null;
        continue;
      }
      final v = _value(value, maxUserPropertyValue);
      final s = v is String ? v : v.toString();
      out[key] =
          s.length > maxUserPropertyValue
              ? s.substring(0, maxUserPropertyValue)
              : s;
    }
    return out;
  }

  /// A screen name for logScreenView (GA4 keeps up to 100 characters).
  static String screenName(String name) =>
      name.length > maxParamValue ? name.substring(0, maxParamValue) : name;
}
