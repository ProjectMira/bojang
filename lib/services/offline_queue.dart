import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Writes the offline queue may hold (plan item #23). Only these: reads are
/// never queued, and anything else keeps failing the old way.
enum QueuedKind {
  /// `POST /progress/complete` (a finished lesson).
  lessonComplete('lesson_complete'),

  /// `POST /progress/activity` (a day of practice, an Earn Back session).
  activity('activity'),

  /// `PATCH /v1/kv/{namespace}`.
  kvPatch('kv_patch'),

  /// `POST /notifications/opened`.
  notificationOpened('notification_opened');

  const QueuedKind(this.id);
  final String id;

  static QueuedKind? fromId(String? id) {
    for (final k in values) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Kinds the server deduplicates by `client_activity_uuid`.
  bool get carriesClientUuid =>
      this == QueuedKind.lessonComplete || this == QueuedKind.activity;
}

/// One write waiting to reach the server. [id] is the client UUID; for
/// [QueuedKind.carriesClientUuid] kinds it is also the body's
/// `client_activity_uuid`, so a replay never counts twice.
@immutable
class QueuedRequest {
  const QueuedRequest({
    required this.id,
    required this.kind,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAt,
    this.uid,
    this.seq,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String id;
  final QueuedKind kind;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final DateTime createdAt;

  /// The account that made it; never sent for another one.
  final String? uid;

  /// Insertion order (the store assigns it). Replays go in this order.
  final int? seq;
  final int attempts;
  final DateTime? nextAttemptAt;

  QueuedRequest copyWith({
    int? seq,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
  }) => QueuedRequest(
    id: id,
    kind: kind,
    method: method,
    path: path,
    body: body,
    createdAt: createdAt,
    uid: uid,
    seq: seq ?? this.seq,
    attempts: attempts ?? this.attempts,
    nextAttemptAt:
        clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
  );

  /// The body as sent: a late delivery says so (`offline: true`) for the
  /// kinds whose server route uses it to credit the original local day.
  Map<String, dynamic> bodyForSend(DateTime now) {
    if (!kind.carriesClientUuid) return body;
    final late =
        attempts > 0 ||
        body['offline'] == true ||
        !_sameDay(createdAt.toLocal(), now.toLocal());
    return {...body, 'client_activity_uuid': id, if (late) 'offline': true};
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Map<String, Object?> toRow() => {
    'id': id,
    'kind': kind.id,
    'method': method,
    'path': path,
    'body': jsonEncode(body),
    'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    'uid': uid,
    'attempts': attempts,
    'next_attempt_at': nextAttemptAt?.toUtc().millisecondsSinceEpoch,
  };

  static QueuedRequest? fromRow(Map<String, Object?> row) {
    final kind = QueuedKind.fromId(row['kind'] as String?);
    if (kind == null) return null;
    try {
      final next = row['next_attempt_at'] as int?;
      return QueuedRequest(
        id: row['id'] as String,
        kind: kind,
        method: row['method'] as String,
        path: row['path'] as String,
        body: Map<String, dynamic>.from(
          jsonDecode(row['body'] as String) as Map,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int,
          isUtc: true,
        ),
        uid: row['uid'] as String?,
        seq: row['seq'] as int?,
        attempts: row['attempts'] as int? ?? 0,
        nextAttemptAt:
            next == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(next, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Where queued writes live. [SqfliteQueueStore] in the app,
/// [MemoryQueueStore] in tests.
abstract class QueueStore {
  /// Every item, oldest first ([QueuedRequest.seq] ascending).
  Future<List<QueuedRequest>> all();

  /// Stores [item] (a new seq is assigned); a known id is left as it is.
  Future<void> add(QueuedRequest item);
  Future<void> update(QueuedRequest item);
  Future<void> remove(String id);
  Future<void> clear();
}

class MemoryQueueStore implements QueueStore {
  final List<QueuedRequest> _items = [];
  int _seq = 0;

  @override
  Future<List<QueuedRequest>> all() async => List.unmodifiable(_items);

  @override
  Future<void> add(QueuedRequest item) async {
    if (_items.any((i) => i.id == item.id)) return;
    _items.add(item.copyWith(seq: ++_seq));
  }

  @override
  Future<void> update(QueuedRequest item) async {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) _items[i] = item;
  }

  @override
  Future<void> remove(String id) async => _items.removeWhere((e) => e.id == id);

  @override
  Future<void> clear() async => _items.clear();
}

/// `offline_queue.db`, table `queued_requests`: survives restarts, so a
/// lesson finished on the bus reaches the server days later.
class SqfliteQueueStore implements QueueStore {
  SqfliteQueueStore({String fileName = 'offline_queue.db'})
    : _fileName = fileName;

  final String _fileName;
  Future<Database>? _db;

  Future<Database> get _open =>
      _db ??= () async {
        final dir = await getDatabasesPath();
        return openDatabase(
          '$dir/$_fileName',
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
          CREATE TABLE queued_requests (
            seq INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT NOT NULL UNIQUE,
            kind TEXT NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            uid TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at INTEGER
          )''');
          },
        );
      }();

  @override
  Future<List<QueuedRequest>> all() async {
    final rows = await (await _open).query('queued_requests', orderBy: 'seq');
    return [
      for (final row in rows)
        if (QueuedRequest.fromRow(row) case final item?) item,
    ];
  }

  @override
  Future<void> add(QueuedRequest item) async {
    await (await _open).insert(
      'queued_requests',
      item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> update(QueuedRequest item) async {
    await (await _open).update(
      'queued_requests',
      item.toRow(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> remove(String id) async {
    await (await _open).delete(
      'queued_requests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clear() async => (await _open).delete('queued_requests');
}

/// Exponential backoff with jitter: 2 s, 4 s, 8 s … capped at 10 minutes.
class OfflineBackoff {
  const OfflineBackoff({
    this.base = const Duration(seconds: 2),
    this.cap = const Duration(minutes: 10),
    this.jitter = 0.2,
  });

  final Duration base;
  final Duration cap;

  /// Up to this fraction is added at random, so phones that come back
  /// online together don't retry in lockstep.
  final double jitter;

  Duration delayFor(int attempts, [Random? random]) {
    final exp = min(attempts - 1, 20).clamp(0, 20);
    final raw = base.inMilliseconds * pow(2, exp);
    final capped = min(raw.toDouble(), cap.inMilliseconds.toDouble());
    final extra =
        jitter <= 0 ? 0.0 : capped * jitter * (random ?? Random()).nextDouble();
    return Duration(milliseconds: (capped + extra).round());
  }
}

/// What sending one queued write did.
enum SendOutcome {
  /// The server took it (2xx). Removed from the queue.
  delivered,

  /// Offline, timed out, 5xx, 401/408/429: try again later.
  retry,

  /// The server refused it for good (other 4xx). Removed, never resent.
  rejected,
}

@immutable
class SendResult {
  const SendResult(this.outcome, {this.status, this.response});
  final SendOutcome outcome;
  final int? status;
  final Map<String, dynamic>? response;

  static SendResult fromStatus(int? status, Map<String, dynamic>? body) {
    if (status == null) return const SendResult(SendOutcome.retry);
    if (status >= 200 && status < 300) {
      return SendResult(SendOutcome.delivered, status: status, response: body);
    }
    const retryable = {401, 408, 425, 429};
    if (status >= 500 || retryable.contains(status)) {
      return SendResult(SendOutcome.retry, status: status);
    }
    return SendResult(SendOutcome.rejected, status: status, response: body);
  }
}

typedef QueueSender = Future<SendResult> Function(QueuedRequest request);
typedef QueueListener = void Function(QueuedRequest request, SendResult result);
typedef QueueAnalytics =
    void Function(String event, Map<String, Object?> props);

/// The persisted request queue (plan item #23, after Duolingo's
/// `@QueuedSuspend` queue).
///
/// [submit] sends a write at once when nothing is waiting, else queues it
/// behind the others; a failed send stays queued. [flush] replays the
/// queue strictly in order, so day N reaches the server before day N+1 and
/// an activity before the lesson after it. It stops at the first item that
/// can't be sent yet and backs off ([OfflineBackoff]); [flush] with
/// `force` (connectivity back, app resumed) ignores the wait. Items older
/// than [maxAge] are dropped: the server no longer accepts them.
class OfflineQueue {
  OfflineQueue({
    required QueueStore store,
    required QueueSender sender,
    String? Function()? uid,
    DateTime Function()? clock,
    OfflineBackoff backoff = const OfflineBackoff(),
    Random? random,
    QueueAnalytics? analytics,
    this.maxAge = const Duration(days: 7),
  }) : _store = store,
       _sender = sender,
       _uid = uid ?? (() => null),
       _clock = clock ?? DateTime.now,
       _backoff = backoff,
       _random = random,
       _analytics = analytics;

  final QueueStore _store;
  final QueueSender _sender;
  final String? Function() _uid;
  final DateTime Function() _clock;
  final OfflineBackoff _backoff;
  final Random? _random;
  final QueueAnalytics? _analytics;
  final Duration maxAge;

  static const _uuid = Uuid();

  final List<QueueListener> _listeners = [];

  /// Number of writes still waiting; Home and the offline banner read it.
  final ValueNotifier<int> pending = ValueNotifier(0);

  Future<void> _tail = Future.value();
  Timer? _retryTimer;

  /// Called after every item that leaves the queue (delivered or rejected).
  void addListener(QueueListener listener) => _listeners.add(listener);
  void removeListener(QueueListener listener) => _listeners.remove(listener);

  /// Runs [job] after every earlier job, so the store is read and written
  /// in one order.
  Future<T> _serial<T>(Future<T> Function() job) {
    final run = _tail.then((_) => job());
    _tail = run.then(
      (_) {},
      onError: (Object e, StackTrace _) {
        debugPrint('Offline queue error: $e');
      },
    );
    return run;
  }

  Future<List<QueuedRequest>> items() => _store.all();

  /// The queued writes of [kind] for the signed-in account.
  Future<List<QueuedRequest>> itemsOf(QueuedKind kind) async => [
    for (final i in await _store.all())
      if (i.kind == kind && i.uid == _uid()) i,
  ];

  /// Adds a write to the end of the queue without sending it.
  Future<QueuedRequest> enqueue(
    QueuedKind kind,
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
    String? id,
  }) => _serial(() => _add(kind, path, body, method, id));

  Future<QueuedRequest> _add(
    QueuedKind kind,
    String path,
    Map<String, dynamic> body,
    String method,
    String? id,
  ) async {
    final item = QueuedRequest(
      id: id ?? _uuid.v4(),
      kind: kind,
      method: method,
      path: path,
      body: body,
      createdAt: _clock().toUtc(),
      uid: _uid(),
    );
    await _store.add(item);
    await _countPending();
    _analytics?.call('offline_queue_enqueued', {'kind': kind.id});
    return item;
  }

  /// Queues a write and sends the queue up to and including it. Returns the
  /// server's answer when it was delivered now, null when it stays queued
  /// (or was rejected: then [rejected] is told).
  Future<SendResult?> submit(
    QueuedKind kind,
    String path,
    Map<String, dynamic> body, {
    String method = 'POST',
  }) => _serial(() async {
    final item = await _add(kind, path, body, method, null);
    try {
      final results = await _drain(force: false, until: item.id);
      return results[item.id];
    } catch (e) {
      debugPrint('Offline queue submit failed: $e');
      return null;
    }
  });

  /// Replays the queue in order. Returns how many items were delivered.
  /// Never throws.
  Future<int> flush({bool force = false}) => _serial(() async {
    try {
      final results = await _drain(force: force);
      return results.values
          .where((r) => r.outcome == SendOutcome.delivered)
          .length;
    } catch (e) {
      debugPrint('Offline queue flush failed: $e');
      return 0;
    }
  });

  Future<Map<String, SendResult>> _drain({
    required bool force,
    String? until,
  }) async {
    final results = <String, SendResult>{};
    final now = _clock();
    final uid = _uid();
    for (final item in await _store.all()) {
      if (item.uid != uid) {
        // Another account's write: never send it as this one. Kept until
        // it expires, in case that account signs back in.
        if (now.difference(item.createdAt) > maxAge) {
          await _store.remove(item.id);
        }
        continue;
      }
      if (now.difference(item.createdAt) > maxAge) {
        await _store.remove(item.id);
        _analytics?.call('offline_queue_dropped', {
          'kind': item.kind.id,
          'reason': 'expired',
          'attempts': item.attempts,
        });
        continue;
      }
      final wait = item.nextAttemptAt;
      if (!force && wait != null && wait.isAfter(now)) {
        _scheduleRetry(wait.difference(now));
        break; // head of line: keep the order
      }
      final SendResult result;
      try {
        result = await _sender(item);
      } catch (e) {
        debugPrint('Offline queue send failed: $e');
        await _backOff(item, now);
        break;
      }
      results[item.id] = result;
      if (result.outcome == SendOutcome.retry) {
        await _backOff(item, now);
        break;
      }
      await _store.remove(item.id);
      if (item.attempts > 0 || result.outcome == SendOutcome.rejected) {
        _analytics?.call(
          result.outcome == SendOutcome.delivered
              ? 'offline_queue_replayed'
              : 'offline_queue_dropped',
          {
            'kind': item.kind.id,
            'attempts': item.attempts,
            'status': result.status,
            'age_minutes': now.difference(item.createdAt).inMinutes,
            if (result.outcome == SendOutcome.rejected) 'reason': 'rejected',
            if (result.outcome == SendOutcome.delivered)
              'replayed': result.response?['replayed'] == true,
          },
        );
      }
      for (final l in List.of(_listeners)) {
        try {
          l(item, result);
        } catch (e) {
          debugPrint('Offline queue listener failed: $e');
        }
      }
      if (item.id == until) break;
    }
    await _countPending();
    return results;
  }

  Future<void> _backOff(QueuedRequest item, DateTime now) async {
    final attempts = item.attempts + 1;
    final delay = _backoff.delayFor(attempts, _random);
    await _store.update(
      item.copyWith(attempts: attempts, nextAttemptAt: now.add(delay)),
    );
    _scheduleRetry(delay);
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> _countPending() async {
    final uid = _uid();
    pending.value = (await _store.all()).where((i) => i.uid == uid).length;
  }

  /// Forgets every queued write (sign-out, reset progress).
  Future<void> clear() => _serial(() async {
    _retryTimer?.cancel();
    await _store.clear();
    pending.value = 0;
  });

  @visibleForTesting
  void dispose() {
    _retryTimer?.cancel();
    pending.dispose();
  }
}
