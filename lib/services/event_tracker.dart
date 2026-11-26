import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import 'crash_reporting.dart';

/// Sends every in-app interaction to the Bojang backend
/// (`POST /analytics/events`, table `app_events`).
///
/// [Analytics] forwards every named event here, and [InteractionCapture]
/// adds taps, swipes and scrolls. This class adds app sessions, screen dwell
/// time and the device context. Events queue in memory, survive app restarts
/// in SharedPreferences, and upload in batches every 20 seconds, at 50
/// queued events, and when the app goes to the background.
class EventTracker with WidgetsBindingObserver {
  EventTracker._();
  static final EventTracker instance = EventTracker._();

  /// A separate tracker for tests (the app uses [instance]).
  @visibleForTesting
  factory EventTracker.forTest() => EventTracker._();

  static const _queueKey = 'analytics_event_queue';
  static const _sessionKey = 'analytics_open_session';
  static const _maxQueue = 2000;
  static const _maxPersisted = 1000;
  static const _batchSize = 200;
  static const _flushAt = 50;
  static const _flushEvery = Duration(seconds: 20);

  /// Back within this time after backgrounding = same session.
  static const sessionTimeout = Duration(minutes: 5);

  /// Uploads one batch and returns the HTTP status (null when offline or
  /// signed out). Replaced in tests.
  @visibleForTesting
  Future<int?> Function(Map<String, Object?> body) sender =
      (body) => ApiService().sendAnalyticsEvents(body);

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Remote Config kill switches (RemoteSettings): stop recording taps,
  /// swipes and scrolls, or pause uploads (events keep queueing, capped).
  bool captureTaps = true;
  bool uploadsEnabled = true;

  /// Server config blocklist and sampling (Analytics.allowsEvent): events
  /// it refuses are not recorded.
  bool Function(String event)? filter;

  /// Debug builds print each event (`[event] tap @tab_home {...}`).
  bool logEvents = const bool.fromEnvironment('LOG_EVENTS');

  final List<Map<String, Object?>> _queue = [];
  @visibleForTesting
  List<Map<String, Object?>> get queue => List.unmodifiable(_queue);

  Map<String, Object?> _context = const {};
  Timer? _timer;
  bool _flushing = false;

  String _sessionId = '';
  String get sessionId => _sessionId;
  int _seq = 0;
  DateTime _sessionStart = DateTime.now();
  DateTime? _foregroundSince;
  Duration _foregroundTotal = Duration.zero;
  DateTime? _pausedAt;
  int _sessionTaps = 0;
  int _sessionScreens = 0;

  String? _screen;
  DateTime? _screenSince;
  Duration _screenAccum = Duration.zero;
  String? get currentScreen => _screen;

  /// Interaction events that only this tracker records (Analytics.track
  /// sends its own to PostHog). [mirror] gets each one as it is queued.
  static const Set<String> mirrored = {
    'tap',
    'long_press',
    'swipe',
    'scroll',
    'rage_tap',
    'multi_touch',
    'screen_exit',
    'app_session_started',
    'app_session_ended',
    'app_backgrounded',
    'app_foregrounded',
  };

  /// Copies [mirrored] events elsewhere (PostHog).
  void Function(String event, String? screen, Map<String, Object?> properties)?
  mirror;

  /// Called with each new session id (Analytics links it into PostHog).
  void Function(String sessionId)? onSessionStarted;

  /// Called with the new screen name whenever the screen on display changes.
  void Function(String screen)? onScreenChanged;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Turns tracking on. Safe to call more than once.
  Future<void> start() async {
    if (_enabled) return;
    _enabled = true;
    try {
      _context = await _buildContext();
    } catch (e) {
      debugPrint('EventTracker context failed: $e');
    }
    await _restoreQueue();
    await _closeSessionLeftOpen();
    WidgetsBinding.instance.addObserver(this);
    _startSession(coldStart: true);
    _timer?.cancel();
    _timer = Timer.periodic(_flushEvery, (_) {
      unawaited(flush());
      unawaited(_persist());
    });
  }

  /// Turns tracking off and forgets anything not yet uploaded (opt-out).
  Future<void> stop() async {
    if (!_enabled) return;
    _enabled = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _queue.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    final now = DateTime.now();
    if (state == AppLifecycleState.paused) {
      if (_pausedAt != null) return;
      final stretch = _foregroundSince == null
          ? Duration.zero
          : now.difference(_foregroundSince!);
      _foregroundTotal += stretch;
      _foregroundSince = null;
      if (_screenSince != null) {
        _screenAccum += now.difference(_screenSince!);
        _screenSince = null;
      }
      _pausedAt = now;
      record('app_backgrounded', properties: {
        'foreground_s': _seconds(stretch),
        'session_foreground_s': _seconds(_foregroundTotal),
      });
      unawaited(_persist());
      unawaited(flush());
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      if (pausedAt == null) return;
      _pausedAt = null;
      final away = now.difference(pausedAt);
      if (away > sessionTimeout) {
        _endSession(at: pausedAt, reason: 'timeout');
        _startSession(coldStart: false);
      } else {
        _foregroundSince = now;
        if (_screen != null) _screenSince = now;
        record('app_foregrounded', properties: {'background_s': _seconds(away)});
      }
    }
  }

  void _startSession({required bool coldStart}) {
    final now = DateTime.now();
    _sessionId = const Uuid().v4();
    _seq = 0;
    _sessionStart = now;
    _foregroundSince = now;
    _foregroundTotal = Duration.zero;
    _pausedAt = null;
    _sessionTaps = 0;
    _sessionScreens = 0;
    if (_screen != null) {
      _screenSince = now;
      _screenAccum = Duration.zero;
    }
    onSessionStarted?.call(_sessionId);
    record('app_session_started', properties: {
      'cold_start': coldStart,
      ..._displayInfo(),
    });
    unawaited(_recordNetwork());
    unawaited(_persist());
  }

  void _endSession({required DateTime at, required String reason}) {
    record(
      'app_session_ended',
      properties: {
        'duration_s': _seconds(_foregroundTotal),
        'wall_s': _seconds(at.difference(_sessionStart)),
        'taps': _sessionTaps,
        'screens': _sessionScreens,
        'reason': reason,
      },
      at: at,
    );
  }

  /// A session the app never got to close (killed in the background or
  /// crashed) is reported on the next launch.
  Future<void> _closeSessionLeftOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw == null) return;
      await prefs.remove(_sessionKey);
      final s = jsonDecode(raw) as Map<String, dynamic>;
      final last = DateTime.tryParse(s['last_seen'] as String? ?? '');
      final start = DateTime.tryParse(s['start'] as String? ?? '');
      if (last == null || start == null) return;
      final event = <String, Object?>{
        'event': 'app_session_ended',
        'ts': last.toUtc().toIso8601String(),
        'session_id': s['id'],
        'seq': s['seq'],
        'screen': s['screen'],
        'properties': {
          'duration_s': s['foreground_s'],
          'wall_s': _seconds(last.difference(start)),
          'taps': s['taps'],
          'screens': s['screens'],
          'reason': s['paused'] == true ? 'killed_in_background' : 'app_terminated',
        },
      };
      _queue.add(event);
    } catch (e) {
      debugPrint('EventTracker session restore failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Queues one event. [screen] defaults to the screen on display.
  void record(
    String event, {
    Map<String, Object?> properties = const {},
    String? screen,
    DateTime? at,
  }) {
    if (!_enabled) return;
    if (event == 'tap' || event == 'long_press') _sessionTaps++;
    // Taps still count towards the session summary when not recorded.
    if (filter != null && !filter!(event)) return;
    if (kDebugMode && logEvents) {
      debugPrint('[event] $event @${screen ?? _screen} $properties');
    }
    _queue.add({
      'event': event,
      'ts': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'session_id': _sessionId,
      'seq': _seq++,
      'screen': screen ?? _screen,
      'properties': _jsonSafe(properties),
    });
    if (mirror != null && mirrored.contains(event)) {
      mirror!(event, screen ?? _screen, _jsonSafe(properties));
    }
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
    if (_queue.length >= _flushAt) unawaited(flush());
  }

  /// The screen on display changed: closes the previous one with its dwell
  /// time (`screen_exit`) and opens the new one (`$screen`).
  void screenChanged(String? name, [Map<String, Object?> properties = const {}]) {
    if (name == null || name.isEmpty || name == _screen) return;
    final now = DateTime.now();
    final previous = _screen;
    if (previous != null) {
      final shown = _screenAccum +
          (_screenSince == null ? Duration.zero : now.difference(_screenSince!));
      record('screen_exit', screen: previous, properties: {
        'duration_ms': shown.inMilliseconds,
        'next_screen': name,
      });
    }
    _screen = name;
    CrashReporting.setKey('screen', name);
    onScreenChanged?.call(name);
    _screenSince = _pausedAt == null ? now : null;
    _screenAccum = Duration.zero;
    _sessionScreens++;
    record(r'$screen', screen: name, properties: {
      ...properties,
      'previous_screen': previous,
    });
  }

  /// Screen names for routes, from `RouteSettings.name` or [manualScreen].
  late final TrackerRouteObserver routeObserver = TrackerRouteObserver._(this);

  /// A screen that is not its own route: a main tab, or a dialog that
  /// [Analytics.screen] names just before showing it.
  void manualScreen(String name, [Map<String, Object?> properties = const {}]) {
    routeObserver._nameTop(name);
    screenChanged(name, properties);
  }

  /// Uploads what is queued. Events stay queued while offline or signed out.
  Future<void> flush() async {
    if (!_enabled || !uploadsEnabled || _flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      while (_enabled && _queue.isNotEmpty) {
        final batch = _queue.take(_batchSize).toList();
        final status = await sender({'context': _context, 'events': batch});
        final retryLater = status == null ||
            status == 401 ||
            status == 403 ||
            status == 404 || // backend without the endpoint yet
            status == 408 ||
            status == 429 ||
            status >= 500;
        if (retryLater) break;
        // Sent (2xx), or refused as malformed (other 4xx): drop either way
        // so one bad batch cannot block the queue.
        final sent = HashSet<Map<String, Object?>>.identity()..addAll(batch);
        _queue.removeWhere(sent.contains);
      }
    } catch (e) {
      debugPrint('EventTracker flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  Future<void> _persist() async {
    if (!_enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tail = _queue.length > _maxPersisted
          ? _queue.sublist(_queue.length - _maxPersisted)
          : _queue;
      await prefs.setString(_queueKey, jsonEncode(tail));
      final now = DateTime.now();
      final foreground = _foregroundTotal +
          (_foregroundSince == null ? Duration.zero : now.difference(_foregroundSince!));
      await prefs.setString(
        _sessionKey,
        jsonEncode({
          'id': _sessionId,
          'seq': _seq,
          'start': _sessionStart.toIso8601String(),
          'last_seen': (_pausedAt ?? now).toIso8601String(),
          'foreground_s': _seconds(foreground),
          'taps': _sessionTaps,
          'screens': _sessionScreens,
          'screen': _screen,
          'paused': _pausedAt != null,
        }),
      );
    } catch (e) {
      debugPrint('EventTracker persist failed: $e');
    }
  }

  Future<void> _restoreQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null) return;
      await prefs.remove(_queueKey);
      for (final e in jsonDecode(raw) as List) {
        if (e is Map) _queue.add(Map<String, Object?>.from(e));
      }
    } catch (e) {
      debugPrint('EventTracker queue restore failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Context
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>> _buildContext() async {
    final info = await PackageInfo.fromPlatform();
    String? model;
    String? os;
    if (!kIsWeb) {
      try {
        final device = DeviceInfoPlugin();
        if (Platform.isIOS) {
          final i = await device.iosInfo;
          model = i.utsname.machine;
          os = '${i.systemName} ${i.systemVersion}';
        } else if (Platform.isAndroid) {
          final a = await device.androidInfo;
          model = '${a.manufacturer} ${a.model}';
          os = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
        }
      } catch (e) {
        debugPrint('EventTracker device info failed: $e');
      }
      os ??= Platform.operatingSystemVersion;
    }
    final now = DateTime.now();
    return {
      'app_version': _cut(info.version, 32),
      'app_build': _cut(info.buildNumber, 16),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'os_version': _cut(os, 128),
      'device_model': _cut(model, 64),
      'locale': kIsWeb ? null : _cut(Platform.localeName, 35),
      'timezone': _cut('${now.timeZoneName} ${_utcOffset(now.timeZoneOffset)}', 64),
    };
  }

  Map<String, Object?> _displayInfo() {
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      final view = dispatcher.implicitView ?? dispatcher.views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      return {
        'screen_w': size.width.round(),
        'screen_h': size.height.round(),
        'pixel_ratio': view.devicePixelRatio,
        'text_scale': dispatcher.textScaleFactor,
        'system_dark_mode': dispatcher.platformBrightness == Brightness.dark,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _recordNetwork() async {
    if (kIsWeb) return;
    try {
      final result = await Connectivity().checkConnectivity();
      record('network_status', properties: {'network': result.name});
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static double _seconds(Duration d) => (d.inMilliseconds / 100).round() / 10;

  static String _utcOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final h = abs.inHours.toString().padLeft(2, '0');
    final m = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }

  static String? _cut(String? s, int max) =>
      s == null || s.length <= max ? s : s.substring(0, max);

  /// Drops nulls, keeps JSON types, shortens long strings (the backend caps
  /// an event's properties at 4 KB).
  static Map<String, Object?> _jsonSafe(Map<String, Object?> properties) {
    Object? clean(Object? v, int depth) {
      if (v == null || v is bool || v is num) return v;
      if (v is String) return _cut(v, 200);
      if (depth > 2) return _cut(v.toString(), 200);
      if (v is Map) {
        return {
          for (final e in v.entries)
            if (e.value != null) e.key.toString(): clean(e.value, depth + 1),
        };
      }
      if (v is Iterable) return v.take(20).map((x) => clean(x, depth + 1)).toList();
      return _cut(v.toString(), 200);
    }

    return {
      for (final e in properties.entries)
        if (e.value != null) e.key: clean(e.value, 0),
    };
  }
}

/// Follows the root Navigator so every event knows its screen and
/// [EventTracker.screenChanged] sees pushes, pops and replacements.
class TrackerRouteObserver extends NavigatorObserver {
  TrackerRouteObserver._(this._tracker);

  final EventTracker _tracker;
  final Expando<String> _names = Expando('screen_name');
  Route<dynamic>? _top;
  _PendingName? _pending;

  void _nameTop(String name) {
    final top = _top;
    _pending = _PendingName(name, top, top == null ? null : _names[top]);
    if (top != null) _names[top] = name;
  }

  String? _nameFor(Route<dynamic> route) {
    final named = _names[route];
    if (named != null) return named;
    final settingsName = route.settings.name;
    if (settingsName != null && settingsName.isNotEmpty) {
      return settingsName == '/' ? 'root' : settingsName;
    }
    if (route is PopupRoute) {
      final kind = route is RawDialogRoute ? 'dialog' : 'popup';
      final name = '${_tracker.currentScreen ?? 'app'}:$kind';
      _names[route] = name;
      return name;
    }
    return 'unnamed_page';
  }

  void _show(Route<dynamic>? route) {
    if (route == null) return;
    _top = route;
    _tracker.screenChanged(_nameFor(route));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final pending = _pending;
    _pending = null;
    if (pending != null &&
        route is PopupRoute &&
        route.settings.name == null &&
        DateTime.now().difference(pending.at) < const Duration(seconds: 1)) {
      // Analytics.screen() named this dialog, not the page under it.
      if (pending.route != null) _names[pending.route!] = pending.previousName;
      _names[route] = pending.name;
      _top = route;
      return;
    }
    _show(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, _top)) _show(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, _top)) _show(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null || identical(oldRoute, _top)) _show(newRoute);
  }
}

class _PendingName {
  _PendingName(this.name, this.route, this.previousName);
  final String name;
  final Route<dynamic>? route;
  final String? previousName;
  final DateTime at = DateTime.now();
}
