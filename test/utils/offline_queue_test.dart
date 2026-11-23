import 'dart:math';

import 'package:bojang/services/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// The persisted offline queue (plan item #23): order, backoff, dedupe.
void main() {
  late DateTime now;
  late List<QueuedRequest> sent;
  late List<SendResult> Function(QueuedRequest) replies;
  late OfflineQueue queue;
  late MemoryQueueStore store;
  var uid = 'learner-1';

  SendResult ok([Map<String, dynamic>? body]) =>
      SendResult(SendOutcome.delivered, status: 200, response: body ?? {});
  const offline = SendResult(SendOutcome.retry);

  OfflineQueue? last;
  OfflineQueue build({List<SendResult> script = const []}) {
    last?.dispose();
    final pendingScript = List.of(script);
    replies = (_) => pendingScript;
    store = MemoryQueueStore();
    return last = OfflineQueue(
      store: store,
      sender: (r) async {
        sent.add(r);
        final s = replies(r);
        return s.isEmpty ? ok() : s.removeAt(0);
      },
      uid: () => uid,
      clock: () => now,
      backoff: const OfflineBackoff(jitter: 0),
    );
  }

  setUp(() {
    now = DateTime(2026, 11, 23, 9);
    sent = [];
    uid = 'learner-1';
    queue = build();
  });

  tearDown(() {
    last?.dispose();
    last = null;
  });

  group('ordering', () {
    test('items replay oldest first, and the queue empties', () async {
      queue = build(script: [offline]);
      // First one fails, so everything after it waits behind it.
      await queue.submit(QueuedKind.activity, 'progress/activity', {
        'local_date': '2026-11-21',
      });
      await queue.submit(QueuedKind.activity, 'progress/activity', {
        'local_date': '2026-11-22',
      });
      await queue.submit(QueuedKind.lessonComplete, 'progress/complete', {
        'session_id': 's1',
      });
      expect(sent.length, 1, reason: 'the head failed; nothing jumps it');
      expect(queue.pending.value, 3);

      sent.clear();
      final delivered = await queue.flush(force: true);
      expect(delivered, 3);
      expect(sent.map((r) => r.body['local_date'] ?? r.body['session_id']), [
        '2026-11-21',
        '2026-11-22',
        's1',
      ]);
      expect(await store.all(), isEmpty);
      expect(queue.pending.value, 0);
    });

    test('a write with nothing queued goes out at once', () async {
      queue = build();
      final result = await queue.submit(
        QueuedKind.notificationOpened,
        'notifications/opened',
        {'notification_id': 'n1'},
      );
      expect(result?.outcome, SendOutcome.delivered);
      expect(sent.single.kind, QueuedKind.notificationOpened);
      expect(await store.all(), isEmpty);
    });

    test('a refused write is dropped and the next one goes', () async {
      queue = build(
        script: [const SendResult(SendOutcome.rejected, status: 422)],
      );
      await queue.enqueue(QueuedKind.lessonComplete, 'progress/complete', {});
      await queue.enqueue(QueuedKind.activity, 'progress/activity', {});
      await queue.flush();
      expect(sent.map((r) => r.kind), [
        QueuedKind.lessonComplete,
        QueuedKind.activity,
      ]);
      expect(await store.all(), isEmpty);
    });

    test('another account’s writes are never sent', () async {
      queue = build();
      uid = 'learner-1';
      await queue.enqueue(QueuedKind.activity, 'progress/activity', {});
      uid = 'learner-2';
      await queue.flush(force: true);
      expect(sent, isEmpty);
      uid = 'learner-1';
      await queue.flush(force: true);
      expect(sent.length, 1);
    });

    test('items older than 7 days are dropped unsent', () async {
      queue = build();
      await queue.enqueue(QueuedKind.activity, 'progress/activity', {});
      now = now.add(const Duration(days: 8));
      await queue.flush(force: true);
      expect(sent, isEmpty);
      expect(await store.all(), isEmpty);
    });
  });

  group('backoff', () {
    test('delays double from 2 s and stop at 10 minutes', () {
      const b = OfflineBackoff(jitter: 0);
      expect(
        [for (var i = 1; i <= 5; i++) b.delayFor(i).inSeconds],
        [2, 4, 8, 16, 32],
      );
      expect(b.delayFor(12), const Duration(minutes: 10));
      expect(b.delayFor(100), const Duration(minutes: 10));
    });

    test('jitter only ever adds, up to 20%', () {
      const b = OfflineBackoff();
      final r = Random(7);
      for (var i = 0; i < 50; i++) {
        final d = b.delayFor(3, r).inMilliseconds;
        expect(d, inInclusiveRange(8000, 9600));
      }
    });

    test('a failed send waits its delay unless forced', () async {
      queue = build(script: [offline, offline]);
      await queue.submit(QueuedKind.activity, 'progress/activity', {});
      var item = (await store.all()).single;
      expect(item.attempts, 1);
      expect(item.nextAttemptAt, now.add(const Duration(seconds: 2)));

      sent.clear();
      now = now.add(const Duration(seconds: 1));
      await queue.flush();
      expect(sent, isEmpty, reason: 'still backing off');

      now = now.add(const Duration(seconds: 2));
      await queue.flush();
      item = (await store.all()).single;
      expect(sent.length, 1);
      expect(item.attempts, 2);
      expect(item.nextAttemptAt, now.add(const Duration(seconds: 4)));

      // Connectivity back / app resumed: try now.
      sent.clear();
      await queue.flush(force: true);
      expect(sent.length, 1);
      expect(await store.all(), isEmpty);
    });

    test('statuses: 5xx, 401 and 429 retry; other 4xx are final', () {
      expect(SendResult.fromStatus(null, null).outcome, SendOutcome.retry);
      expect(SendResult.fromStatus(503, null).outcome, SendOutcome.retry);
      expect(SendResult.fromStatus(401, null).outcome, SendOutcome.retry);
      expect(SendResult.fromStatus(429, null).outcome, SendOutcome.retry);
      expect(SendResult.fromStatus(409, null).outcome, SendOutcome.rejected);
      expect(SendResult.fromStatus(410, null).outcome, SendOutcome.rejected);
      expect(SendResult.fromStatus(201, {}).outcome, SendOutcome.delivered);
    });
  });

  group('dedupe', () {
    test('every attempt of an item sends the same client uuid', () async {
      queue = build(script: [offline, offline]);
      await queue.submit(QueuedKind.lessonComplete, 'progress/complete', {
        'session_id': 's1',
        'local_date': '2026-11-23',
      });
      await queue.flush(force: true);
      await queue.flush(force: true);
      final ids = sent.map((r) => r.bodyForSend(now)['client_activity_uuid']);
      expect(ids.toSet().length, 1);
      expect(ids.first, sent.first.id);
    });

    test('a late send is marked offline; a first try the same day is not', () {
      final item = QueuedRequest(
        id: 'u-1',
        kind: QueuedKind.activity,
        method: 'POST',
        path: 'progress/activity',
        body: const {'local_date': '2026-11-23'},
        createdAt: now,
      );
      expect(item.bodyForSend(now).containsKey('offline'), isFalse);
      expect(item.copyWith(attempts: 1).bodyForSend(now)['offline'], isTrue);
      expect(
        item.bodyForSend(now.add(const Duration(days: 1)))['offline'],
        isTrue,
      );
      // The day played is kept as it was.
      expect(
        item.bodyForSend(now.add(const Duration(days: 3)))['local_date'],
        '2026-11-23',
      );
    });

    test('kv patches and push opens carry no client uuid', () {
      final item = QueuedRequest(
        id: 'u-2',
        kind: QueuedKind.kvPatch,
        method: 'PATCH',
        path: 'v1/kv/tips',
        body: const {'items': []},
        createdAt: now,
        attempts: 3,
      );
      expect(item.bodyForSend(now), const {'items': []});
    });

    test('the same id is stored once', () async {
      queue = build();
      final s = MemoryQueueStore();
      final item = QueuedRequest(
        id: 'same',
        kind: QueuedKind.activity,
        method: 'POST',
        path: 'p',
        body: const {},
        createdAt: now,
      );
      await s.add(item);
      await s.add(item);
      expect((await s.all()).length, 1);
    });

    test('rows survive a round trip through the store format', () {
      final item = QueuedRequest(
        id: 'row-1',
        kind: QueuedKind.lessonComplete,
        method: 'POST',
        path: 'progress/complete',
        body: const {'xp_earned': 50},
        createdAt: now.toUtc(),
        uid: 'learner-1',
        attempts: 2,
        nextAttemptAt: now.toUtc(),
      );
      final back = QueuedRequest.fromRow({...item.toRow(), 'seq': 4})!;
      expect(back.id, 'row-1');
      expect(back.kind, QueuedKind.lessonComplete);
      expect(back.body['xp_earned'], 50);
      expect(back.attempts, 2);
      expect(back.seq, 4);
      expect(back.createdAt, now.toUtc());
    });
  });
}
