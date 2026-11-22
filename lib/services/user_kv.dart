import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Sends one request to the backend and returns the raw response (null when
/// offline). Replaced in tests.
typedef KvTransport =
    Future<http.Response?> Function(
      String method,
      String endpoint, {
      Object? body,
    });

/// One stored value and the version the server holds for it.
@immutable
class KvEntry {
  const KvEntry(this.value, this.version);

  final Object? value;

  /// Starts at 1, goes up by one per write. 0 = not stored.
  final int version;

  static KvEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    if (version is! int) return null;
    return KvEntry(json['value'], version);
  }

  Map<String, Object?> toJson() => {'value': value, 'version': version};
}

/// One change for [UserKv.write]. [version] is the version last read (0 for
/// a key believed not to exist).
@immutable
class KvWrite {
  const KvWrite.set(this.key, this.value, {required this.version})
    : delete = false;
  const KvWrite.delete(this.key, {required this.version})
    : value = null,
      delete = true;

  final String key;
  final Object? value;
  final int version;
  final bool delete;

  Map<String, Object?> toJson() => {
    'key': key,
    if (!delete) 'value': value,
    'version': version,
    if (delete) 'delete': true,
  };
}

enum KvOutcome { ok, conflict, failed }

/// What a write did. On [KvOutcome.ok], [entries] is the whole namespace;
/// on [KvOutcome.conflict], [entries] holds the stored state of the keys in
/// [conflicts] (a key missing from it no longer exists).
@immutable
class KvWriteResult {
  const KvWriteResult(
    this.outcome, {
    this.entries = const {},
    this.conflicts = const [],
  });

  final KvOutcome outcome;
  final Map<String, KvEntry> entries;
  final List<String> conflicts;
}

/// Client for the backend's per-learner key-value store,
/// `GET|PATCH /v1/kv/{namespace}` (plan item #22).
///
/// Each namespace is mirrored on the device (per signed-in uid), so reads
/// work offline and after a restart. Writes are version-checked by the
/// server; [update] does read-modify-write with retries, which is what most
/// callers want. Small state only: at most 200 keys of 8 KB per namespace.
///
/// Ready-made helpers: [OnboardingAnswers], [SeenTips], [FeatureState].
class UserKv {
  UserKv({KvTransport? transport, String Function()? uid})
    : _transport = transport ?? _defaultTransport,
      _uid = uid ?? _defaultUid;

  static final UserKv instance = UserKv();

  static Future<http.Response?> _defaultTransport(
    String method,
    String endpoint, {
    Object? body,
  }) => ApiService().rawRequest(method, endpoint, body: body);

  /// The local copy is kept per Firebase uid, so a second account on the
  /// phone never sees the first one's state.
  static String _defaultUid() {
    try {
      if (Firebase.apps.isEmpty) return 'none';
      return FirebaseAuth.instance.currentUser?.uid ?? 'none';
    } catch (_) {
      return 'none';
    }
  }

  final KvTransport _transport;
  final String Function() _uid;
  static const int maxRetries = 3;

  final Map<String, Map<String, KvEntry>> _memory = {};

  String _prefsKey(String namespace) => 'user_kv_${_uid()}_$namespace';

  /// The local copy of [namespace]: what the last read or write returned.
  Future<Map<String, KvEntry>> cached(String namespace) async {
    final key = _prefsKey(namespace);
    final inMemory = _memory[key];
    if (inMemory != null) return inMemory;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final entries = <String, KvEntry>{
          for (final e in decoded.entries)
            if (KvEntry.fromJson(e.value) case final entry?) e.key: entry,
        };
        return _memory[key] = entries;
      }
    } catch (e) {
      debugPrint('user_kv cache unreadable: $e');
    }
    return const {};
  }

  Future<void> _store(String namespace, Map<String, KvEntry> entries) async {
    final key = _prefsKey(namespace);
    _memory[key] = Map.unmodifiable(entries);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({for (final e in entries.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }

  static Map<String, KvEntry> _parseItems(Object? items) => {
    if (items is Map)
      for (final e in items.entries)
        if (KvEntry.fromJson(e.value) case final entry?)
          e.key.toString(): entry,
  };

  /// Fresh copy of [namespace] from the server (also stored locally), or the
  /// local copy when the server cannot be reached.
  Future<Map<String, KvEntry>> read(String namespace) async {
    final response = await _transport('GET', '/v1/kv/$namespace');
    if (response == null || response.statusCode != 200) {
      return cached(namespace);
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = _parseItems(body['items']);
      await _store(namespace, entries);
      return entries;
    } catch (_) {
      return cached(namespace);
    }
  }

  /// Sends [writes] as one all-or-nothing batch.
  Future<KvWriteResult> write(String namespace, List<KvWrite> writes) async {
    if (writes.isEmpty) {
      return KvWriteResult(KvOutcome.ok, entries: await cached(namespace));
    }
    final response = await _transport(
      'PATCH',
      '/v1/kv/$namespace',
      body: {
        'items': [for (final w in writes) w.toJson()],
      },
    );
    if (response == null) return const KvWriteResult(KvOutcome.failed);
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        final entries = _parseItems(body['items']);
        await _store(namespace, entries);
        return KvWriteResult(KvOutcome.ok, entries: entries);
      }
      if (response.statusCode == 409) {
        final detail = body['detail'] as Map<String, dynamic>;
        final current = _parseItems(detail['current']);
        final conflicts = [
          for (final k in detail['conflicts'] as List) k.toString(),
        ];
        // Fold what the server holds into the local copy.
        final merged = Map<String, KvEntry>.of(await cached(namespace));
        for (final key in conflicts) {
          final entry = current[key];
          if (entry == null) {
            merged.remove(key);
          } else {
            merged[key] = entry;
          }
        }
        await _store(namespace, merged);
        return KvWriteResult(
          KvOutcome.conflict,
          entries: current,
          conflicts: conflicts,
        );
      }
    } catch (e) {
      debugPrint('user_kv write answer unreadable: $e');
    }
    return const KvWriteResult(KvOutcome.failed);
  }

  /// Read-modify-write of one key: [change] gets the stored value (null when
  /// absent) and returns the new one (null deletes the key). On a version
  /// conflict it runs again on the server's value, up to [maxRetries] times.
  /// Returns the stored entry, or null when it was deleted or the write
  /// failed (offline).
  Future<KvEntry?> update(
    String namespace,
    String key,
    Object? Function(Object? current) change,
  ) async {
    var current = (await cached(namespace))[key];
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final next = change(current?.value);
      final version = current?.version ?? 0;
      final result = await write(namespace, [
        next == null
            ? KvWrite.delete(key, version: version)
            : KvWrite.set(key, next, version: version),
      ]);
      switch (result.outcome) {
        case KvOutcome.ok:
          return result.entries[key];
        case KvOutcome.failed:
          return null;
        case KvOutcome.conflict:
          current = result.entries[key];
      }
    }
    return null;
  }

  /// Forgets the local copies (sign-out, account deletion).
  Future<void> clearLocal() async {
    _memory.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where(
        (k) => k.startsWith('user_kv_'),
      )) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}

/// Onboarding answers (namespace `onboarding`): why the learner is here,
/// how much Tibetan they know, their voice and daily goal (plan item #8).
class OnboardingAnswers {
  OnboardingAnswers([UserKv? kv]) : _kv = kv ?? UserKv.instance;

  static const String namespace = 'onboarding';
  final UserKv _kv;

  /// Saves one answer, e.g. `save('motivation', 'heritage')`. The latest
  /// answer wins over whatever another device stored.
  Future<bool> save(String question, Object answer) async =>
      await _kv.update(namespace, question, (_) => answer) != null;

  /// All answers, from the server when reachable, else the local copy.
  Future<Map<String, Object?>> load() async => {
    for (final e in (await _kv.read(namespace)).entries) e.key: e.value.value,
  };
}

/// Tips, tooltips and one-time prompts already shown (namespace `tips`).
/// Seen is permanent, so merging is trivial: once true, always true.
class SeenTips {
  SeenTips([UserKv? kv]) : _kv = kv ?? UserKv.instance;

  static const String namespace = 'tips';
  final UserKv _kv;

  /// From the local copy, so it is instant and works offline. Call
  /// [refresh] once after sign-in to pick up other devices.
  Future<bool> hasSeen(String tip) async =>
      (await _kv.cached(namespace))[tip]?.value != null;

  /// Marks [tip] seen. Returns false when offline; the tip may then show
  /// again on the next launch, which is harmless.
  Future<bool> markSeen(String tip) async {
    if (await hasSeen(tip)) return true;
    final stamp = DateTime.now().toUtc().toIso8601String();
    return await _kv.update(namespace, tip, (current) => current ?? stamp) !=
        null;
  }

  Future<void> refresh() => _kv.read(namespace);
}

/// Small per-feature state (namespace `features`): counters, timers,
/// "dismissed until" dates. One key per feature, any JSON value.
class FeatureState {
  FeatureState([UserKv? kv]) : _kv = kv ?? UserKv.instance;

  static const String namespace = 'features';
  final UserKv _kv;

  Future<Object?> get(String feature) async =>
      (await _kv.cached(namespace))[feature]?.value;

  /// Read-modify-write that survives other devices writing in between.
  Future<Object?> update(
    String feature,
    Object? Function(Object?) change,
  ) async => (await _kv.update(namespace, feature, change))?.value;

  Future<void> refresh() => _kv.read(namespace);
}
