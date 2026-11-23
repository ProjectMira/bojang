import 'dart:io';
import 'dart:typed_data';

import 'package:bojang/services/lesson_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prefetched lessons and the 50 MB media cache (plan item #23).
void main() {
  late Directory root;
  late DateTime now;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bojang_offline_');
    now = DateTime(2026, 11, 23, 9);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  OfflineMediaCache cache({int cap = 1000}) => OfflineMediaCache(
    directory: () async => Directory('${root.path}/media'),
    capBytes: cap,
    clock: () => now,
  );

  Uint8List bytes(int n) => Uint8List(n);

  group('media cache cap', () {
    test('the least recently used files go first', () async {
      final c = cache(cap: 1000);
      await c.put('https://cdn/a.mp3', bytes(400));
      now = now.add(const Duration(minutes: 1));
      await c.put('https://cdn/b.mp3', bytes(400));
      now = now.add(const Duration(minutes: 1));
      await c.fileFor('https://cdn/a.mp3'); // a is used again
      now = now.add(const Duration(minutes: 1));
      await c.put('https://cdn/c.jpg', bytes(400));

      expect(await c.contains('https://cdn/a.mp3'), isTrue);
      expect(await c.contains('https://cdn/b.mp3'), isFalse);
      expect(await c.contains('https://cdn/c.jpg'), isTrue);
      expect(await c.totalBytes(), 800);
      expect(await c.totalBytes(), lessThanOrEqualTo(1000));
    });

    test('a file bigger than the cap is not kept', () async {
      final c = cache(cap: 100);
      expect(await c.put('https://cdn/big.jpg', bytes(101)), isFalse);
      expect(await c.totalBytes(), 0);
    });

    test('the manifest survives a restart', () async {
      await cache().put('https://cdn/a.mp3', bytes(10));
      final again = cache();
      expect(await again.contains('https://cdn/a.mp3'), isTrue);
      expect((await again.fileFor('https://cdn/a.mp3'))!.lengthSync(), 10);
      expect(again.fileForSync('https://cdn/a.mp3'), isNotNull);
    });

    test('the default cap is 50 MB', () {
      expect(cache(cap: 50 * 1024 * 1024).capBytes, 52428800);
      expect(OfflineMediaCache(directory: () async => root).capBytes, 52428800);
    });
  });

  group('prefetch', () {
    late int fetched;
    late List<String> downloads;
    late Map<String, String> lastQuery;

    Map<String, dynamic> session(String id, {DateTime? expires}) => {
      'session_id': id,
      'level_id': 'basics_1',
      if (expires != null) 'expires_at': expires.toUtc().toIso8601String(),
      'exercises': [
        {
          'type': 'picture_choice',
          'image_url': 'https://cdn/img/$id.jpg',
          'audio_url': 'https://cdn/default/$id.mp3',
          'audio_urls': {
            'lhasa_female': 'https://cdn/lhasa/$id.mp3',
            'kham_male': 'https://cdn/kham/$id.mp3',
          },
        },
        {'type': 'multiple_choice', 'image_url': 'https://cdn/no/$id.jpg'},
      ],
    };

    LessonPrefetcher prefetcher({String voice = 'kham_male'}) =>
        LessonPrefetcher(
          directory: () async => Directory('${root.path}/sessions'),
          fetchSession: (level, query) async {
            lastQuery = query;
            fetched++;
            return session('s$fetched');
          },
          download: (url) async {
            downloads.add(url);
            return bytes(10);
          },
          media: cache(cap: 10000),
          voice: () => voice,
          clock: () => now,
        );

    setUp(() {
      fetched = 0;
      downloads = [];
      lastQuery = {};
    });

    test('keeps two lessons of the active level with their media', () async {
      final p = prefetcher();
      await p.setActiveLevel('basics_1', {'supported_types': 'a,b'});
      expect(await p.prefetch(), 2);
      expect(p.ready.value, 2);
      expect(lastQuery, {'supported_types': 'a,b'});
      // The learner's voice and the picture, not the other voice.
      expect(
        downloads,
        containsAll(['https://cdn/kham/s1.mp3', 'https://cdn/img/s1.jpg']),
      );
      expect(downloads, isNot(contains('https://cdn/lhasa/s1.mp3')));
      expect(downloads, isNot(contains('https://cdn/no/s1.jpg')));

      expect(await p.prefetch(), 0, reason: 'already topped up');
      expect(fetched, 2);
    });

    test('take hands out the oldest once, marked offline', () async {
      final p = prefetcher();
      await p.setActiveLevel('basics_1', {});
      await p.prefetch();
      final first = await p.take('basics_1');
      expect(first!['session_id'], 's1');
      expect(first['offline'], isTrue);
      expect(p.ready.value, 1);
      expect((await p.take('basics_1'))!['session_id'], 's2');
      expect(await p.take('basics_1'), isNull);
      expect(p.ready.value, 0);
    });

    test('expired sessions are thrown away', () async {
      final p = prefetcher();
      await p.setActiveLevel('basics_1', {});
      await p.prefetch();
      now = now.add(const Duration(days: 8));
      expect(await p.take('basics_1'), isNull);
    });

    test('stored sessions survive a restart', () async {
      final p = prefetcher();
      await p.setActiveLevel('basics_1', {});
      await p.prefetch();
      final again = prefetcher();
      expect(await again.activeLevel(), 'basics_1');
      expect(await again.readyFor('basics_1'), 2);
    });

    test('media urls follow the voice fallback', () {
      final urls = LessonPrefetcher.mediaUrls(session('x'), 'amdo_unknown');
      expect(urls, contains('https://cdn/lhasa/x.mp3')); // default voice
      expect(urls, contains('https://cdn/img/x.jpg'));
    });
  });
}
