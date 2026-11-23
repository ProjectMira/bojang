import 'package:bojang/services/offline_queue.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/utils/offline_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optimistic XP, streak and Earn Back while writes wait in the offline
/// queue (plan item #23).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  QueuedRequest item(QueuedKind kind, Map<String, dynamic> body) =>
      QueuedRequest(
        id: '${kind.id}-${body.hashCode}',
        kind: kind,
        method: 'POST',
        path: 'p',
        body: body,
        createdAt: DateTime(2026, 11, 23),
      );

  group('PendingProgress', () {
    test('sums queued lesson XP and activity days', () {
      final p = PendingProgress.of([
        item(QueuedKind.lessonComplete, {'xp_earned': 80}),
        item(QueuedKind.lessonComplete, {'xp_earned': 50}),
        item(QueuedKind.activity, {'local_date': '2026-11-22'}),
        item(QueuedKind.activity, {'local_date': '2026-11-23'}),
        item(QueuedKind.kvPatch, {'items': []}),
      ]);
      expect((p.xp, p.lessons, p.activities), (130, 2, 2));
      expect(p.activityDays, {'2026-11-22', '2026-11-23'});
      expect(p.mergeXp(server: 1000), 1130);
    });

    test('the device streak wins only while days are unsent', () {
      const none = PendingProgress.none;
      final queued = PendingProgress.of([
        item(QueuedKind.activity, {'local_date': '2026-11-22'}),
      ]);
      expect(none.mergeStreak(server: 4, local: 6, playedToday: false), 4);
      expect(none.mergeStreak(server: 4, local: 6, playedToday: true), 6);
      expect(queued.mergeStreak(server: 4, local: 6, playedToday: false), 6);
      // A higher server count (another device) always wins.
      expect(queued.mergeStreak(server: 9, local: 6, playedToday: true), 9);
      expect(none.mergeXp(server: 10), 10);
    });
  });

  group('ProgressService with the offline queue', () {
    late MemoryQueueStore store;
    late OfflineQueue queue;
    late bool online;
    late List<QueuedRequest> sent;
    Map<String, dynamic> activityReply = const {};

    Future<ProgressService> build() async {
      SharedPreferences.setMockInitialValues({
        'pending_activity_dates': ['2026-01-01'],
      });
      store = MemoryQueueStore();
      sent = [];
      queue = OfflineQueue(
        store: store,
        sender: (r) async {
          if (!online) return const SendResult(SendOutcome.retry);
          sent.add(r);
          return SendResult(
            SendOutcome.delivered,
            status: 200,
            response: r.kind == QueuedKind.activity ? activityReply : {},
          );
        },
        uid: () => 'me',
        backoff: const OfflineBackoff(jitter: 0),
        maxAge: const Duration(days: 36500),
      );
      final service = ProgressService(
        isSignedIn: () => true,
        offlineQueue: queue,
        fetchStats: () async => null,
      );
      await pumpEventQueue();
      return service;
    }

    tearDown(() => queue.dispose());

    test('offline: XP and streak stay on screen until the replay', () async {
      online = false;
      final service = await build();
      await service.updateQuizResults('topic', 8, 10);
      await pumpEventQueue();
      expect(service.xp, 80);
      expect(service.currentStreak, 1);

      // The finished lesson waits in the queue too.
      await queue.submit(QueuedKind.lessonComplete, 'progress/complete', {
        'session_id': 's1',
        'xp_earned': 80,
      });
      // Stale server stats (before either reached it) must not undo them.
      await service.updateFromServer({
        'xp': {'total': 0},
        'streak': {'current': 0},
        'league': {'current': 'Bronze'},
      });
      expect(service.xp, 80);
      expect(service.currentStreak, 1);
      expect(service.pendingProgress.lessons, 1);
      expect(service.pendingProgress.activities, 2); // legacy day + today

      // Back online: the queue drains in order and the server's answer
      // replaces the guess.
      online = true;
      activityReply = {
        'streak': 1,
        'streak_extended': true,
        'earn_back': {'active': false},
      };
      await service.flushPendingActivity();
      await pumpEventQueue();
      expect(sent.map((r) => r.kind), [
        QueuedKind.activity, // moved over from the old pending list
        QueuedKind.activity,
        QueuedKind.lessonComplete,
      ]);
      expect(sent.first.bodyForSend(DateTime.now())['offline'], isTrue);
      expect(service.pendingProgress.isEmpty, isTrue);
      await service.updateFromServer({
        'xp': {'total': 95},
        'streak': {'current': 1},
      });
      expect(service.xp, 95);
    });

    test('every queued report has its own client uuid', () async {
      online = false;
      final service = await build();
      await service.updateQuizResults('topic', 5, 5);
      await service.updateQuizResults('topic', 5, 5);
      await pumpEventQueue();
      final ids = (await store.all()).map((r) => r.id).toSet();
      expect(ids.length, 3); // legacy day + two sessions today
    });

    test('an Earn Back session counted offline is kept', () async {
      online = false;
      final service = await build();
      final today = DateTime.now();
      final last = DateTime(today.year, today.month, today.day - 2);
      SharedPreferences.setMockInitialValues({
        'current_streak': 10,
        'last_play_date': last.toIso8601String(),
      });
      final fresh = ProgressService(
        isSignedIn: () => true,
        offlineQueue: queue,
        fetchStats: () async => null,
      );
      await pumpEventQueue();
      await fresh.updateQuizResults('topic', 5, 5);
      await pumpEventQueue();
      expect(fresh.earnBack?.sessionsDone, 1);
      // A server that hasn't seen the session yet doesn't erase it.
      await fresh.updateFromServer({
        'xp': {'total': 0},
        'streak': {
          'current': 0,
          'earn_back': fresh.earnBack!.toJson()..['sessions_done'] = 0,
        },
      });
      expect(fresh.earnBack?.sessionsDone, 1);
      service.dispose();
      fresh.dispose();
    });
  });
}
