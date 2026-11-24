import 'package:flutter_test/flutter_test.dart';

import 'package:bojang/models/learning_path.dart';

/// A path as GET /learn/path sends it: Basics passed up to the active step,
/// the reading check opening Unit 2.
Map<String, dynamic> samplePathJson({String active = 'lesson:basics-vowels'}) =>
    {
      'active_node_id': active,
      'gate_skipped': false,
      'daily': {'sessions': 1, 'goal': 2},
      'units': [
        {
          'id': 'path-basics',
          'index': 1,
          'title': 'Tibetan Basics',
          'description': 'Letters first',
          'state': 'active',
          'nodes': [
            {
              'id': 'lesson:basics-letters-1',
              'type': 'lesson',
              'subtype': 'script',
              'state': 'passed',
              'title': 'Letters 1',
              'level_id': 'basics-letters-1',
              'finished_sessions': 3,
              'total_sessions': 3,
              'session_words': 5,
              'has_lesson': true,
            },
            {
              'id': 'lesson:basics-vowels',
              'type': 'lesson',
              'subtype': 'script',
              'state': active == 'lesson:basics-vowels' ? 'active' : 'passed',
              'title': 'The four vowels',
              'level_id': 'basics-vowels',
              'finished_sessions': 1,
              'total_sessions': 3,
              'session_words': 6,
              'has_lesson': true,
            },
            {
              'id': 'unit_review:path-basics',
              'type': 'unit_review',
              'subtype': 'unit_review',
              'state': active == 'alphabet_gate:script' ? 'passed' : 'locked',
              'title': 'Review: Tibetan Basics',
              'level_id': null,
              'finished_sessions': 0,
              'total_sessions': 1,
            },
          ],
        },
        {
          'id': 'path-first-words',
          'index': 2,
          'title': 'First words',
          'state': 'locked',
          'nodes': [
            {
              'id': 'alphabet_gate:script',
              'type': 'alphabet_gate',
              'subtype': 'script',
              'state': active == 'alphabet_gate:script' ? 'active' : 'locked',
              'title': 'Reading check',
              'route': '/script/gate',
              'finished_sessions': 0,
              'total_sessions': 1,
            },
            {
              'id': 'lesson:vocab-number',
              'type': 'lesson',
              'subtype': 'vocabulary',
              'state': 'locked',
              'title': 'Number',
              'level_id': 'vocab-number',
              'finished_sessions': 0,
              'total_sessions': 3,
              'session_words': 5,
            },
          ],
        },
      ],
    };

void main() {
  group('LearningPath.fromJson', () {
    final path = LearningPath.fromJson(samplePathJson());

    test('reads units and nodes in order', () {
      expect(path.units.map((u) => u.index), [1, 2]);
      expect(path.nodes.map((n) => n.id).first, 'lesson:basics-letters-1');
      expect(path.nodes.length, 5);
      expect(path.units.first.passedCount, 1);
      expect(path.units.last.isLocked, isTrue);
    });

    test('reads node fields and the session ring', () {
      final active = path.activeNode!;
      expect(active.id, 'lesson:basics-vowels');
      expect(active.isActive, isTrue);
      expect(active.finishedSessions, 1);
      expect(active.totalSessions, 3);
      expect(active.progress, closeTo(1 / 3, 1e-9));
      expect(active.hasLesson, isTrue);
      final gate = path.nodes.firstWhere(
        (n) => n.type == PathNodeType.alphabetGate,
      );
      expect(gate.route, '/script/gate');
      expect(gate.isLocked, isTrue);
      expect(
        path.nodes
            .firstWhere((n) => n.type == PathNodeType.unitReview)
            .isReview,
        isTrue,
      );
    });

    test('reads the daily goal (sessions a day)', () {
      expect(path.daily!.sessions, 1);
      expect(path.daily!.goal, 2);
      expect(path.daily!.progress, 0.5);
      expect(path.daily!.reached, isFalse);
    });

    test('tolerates missing and unknown fields', () {
      final p = LearningPath.fromJson({
        'units': [
          {
            'nodes': [
              {'id': 'story:x', 'type': 'story', 'state': 'weird'},
            ],
          },
        ],
      });
      expect(p.units.single.index, 1);
      final node = p.units.single.nodes.single;
      expect(node.state, PathNodeState.locked);
      expect(node.totalSessions, 1);
      expect(p.daily, isNull);
      expect(p.activeNode, isNull);
    });
  });

  group('lockedReason', () {
    test('names the active step in the same unit', () {
      final path = LearningPath.fromJson(samplePathJson());
      final review = path.nodes.firstWhere(
        (n) => n.id == 'unit_review:path-basics',
      );
      expect(path.lockedReason(review), contains('The four vowels'));
    });

    test('points at the unit to finish for a later unit', () {
      final path = LearningPath.fromJson(samplePathJson());
      final number = path.nodes.firstWhere(
        (n) => n.id == 'lesson:vocab-number',
      );
      expect(path.lockedReason(number), contains('Finish Unit 1'));
      expect(path.lockedReason(number), contains('Unit 2'));
    });

    test('explains the reading check when it blocks', () {
      final path = LearningPath.fromJson(
        samplePathJson(active: 'alphabet_gate:script'),
      );
      final number = path.nodes.firstWhere(
        (n) => n.id == 'lesson:vocab-number',
      );
      expect(path.lockedReason(number), contains('reading check'));
    });

    test('is empty for reachable steps', () {
      final path = LearningPath.fromJson(samplePathJson());
      expect(path.lockedReason(path.activeNode!), isEmpty);
    });
  });

  group('review topic paths', () {
    test('round-trip a node id', () {
      expect(reviewTopicPath(), 'api://review');
      expect(reviewNodeIdOf(reviewTopicPath()), isNull);
      expect(
        reviewNodeIdOf(reviewTopicPath('practice:path-basics')),
        'practice:path-basics',
      );
      expect(reviewNodeIdOf('api://level/x'), isNull);
    });
  });

  test('ReviewSummary.fromJson', () {
    final s = ReviewSummary.fromJson({
      'word_count': 3,
      'mistake_count': 2,
      'weak_count': 1,
      'words': [
        {
          'lexeme_id': 'w',
          'tibetan': 'ཆུ',
          'english': 'water',
          'label': 'mistake',
          'attempts': 2,
          'correct': 1,
          'audio_urls': {'lhasa_female': 'https://x/a.wav'},
        },
      ],
    });
    expect(s.wordCount, 3);
    expect(s.words.single.label, 'mistake');
    expect(s.words.single.audioUrls['lhasa_female'], 'https://x/a.wav');
  });

  group('ReviewSummary FSRS fields', () {
    test('an older server without them: FSRS off, defaults', () {
      final s = ReviewSummary.fromJson({
        'word_count': 1,
        'mistake_count': 1,
        'weak_count': 0,
        'words': [
          {
            'lexeme_id': 'w',
            'tibetan': 'ཆུ',
            'english': 'water',
            'label': 'mistake',
          },
        ],
      });
      expect(s.fsrsEnabled, isFalse);
      expect(s.dueCount, 0);
      expect(s.trackedCount, 0);
      expect(s.sessionSize, 0);
      expect(s.nextDueAt, isNull);
      expect(s.dueWords, isEmpty);
      expect(s.words.single.dueAt, isNull);
      expect(s.allWords.map((w) => w.lexemeId), ['w']);
    });

    test('a new server: due words, next due, tracked', () {
      final s = ReviewSummary.fromJson({
        'word_count': 1,
        'mistake_count': 1,
        'weak_count': 0,
        'words': [
          {
            'lexeme_id': 'w1',
            'tibetan': 'ཆུ',
            'english': 'water',
            'label': 'mistake',
          },
        ],
        'fsrs_enabled': true,
        'due_count': 2,
        'next_due_at': '2026-11-24T15:00:00Z',
        'tracked_count': 42,
        'session_size': 3,
        'due_words': [
          {
            'lexeme_id': 'w2',
            'tibetan': 'ཁ་ལག',
            'english': 'food',
            'label': 'due',
            'due_at': '2026-11-20T08:00:00+00:00',
          },
          {
            'lexeme_id': 'w1',
            'tibetan': 'ཆུ',
            'english': 'water',
            'label': 'mistake',
            'due_at': '2026-11-23T08:00:00+00:00',
          },
        ],
      });
      expect(s.fsrsEnabled, isTrue);
      expect(s.dueCount, 2);
      expect(s.trackedCount, 42);
      expect(s.sessionSize, 3);
      expect(s.nextDueAt, DateTime.utc(2026, 11, 24, 15));
      expect(s.dueWords.first.dueAt, DateTime.utc(2026, 11, 20, 8));
      // Due first, no duplicates.
      expect(s.allWords.map((w) => w.lexemeId), ['w2', 'w1']);
      final old = s.withoutFsrs();
      expect(old.fsrsEnabled, isFalse);
      expect(old.dueCount, 0);
      expect(old.words.single.lexemeId, 'w1');
    });

    test('bad values fall back instead of throwing', () {
      final s = ReviewSummary.fromJson({
        'word_count': 0,
        'fsrs_enabled': 'yes',
        'next_due_at': 'not a date',
        'due_words': 'nope',
        'tracked_count': null,
      });
      expect(s.fsrsEnabled, isFalse);
      expect(s.nextDueAt, isNull);
      expect(s.dueWords, isEmpty);
      expect(s.trackedCount, 0);
    });
  });

  group('nextReviewPhrase', () {
    final now = DateTime(2026, 11, 24, 9);
    test('minutes, hours, tomorrow, days', () {
      expect(
        nextReviewPhrase(now.add(const Duration(minutes: 10)), now),
        'in 10 min',
      );
      expect(
        nextReviewPhrase(now.add(const Duration(hours: 3)), now),
        'in 3 h',
      );
      expect(nextReviewPhrase(DateTime(2026, 11, 25, 10), now), 'tomorrow');
      expect(nextReviewPhrase(DateTime(2026, 11, 28, 10), now), 'in 4 days');
      expect(
        nextReviewPhrase(now.subtract(const Duration(minutes: 5)), now),
        'now',
      );
    });
    test('late evening: a few hours away reads in hours, not tomorrow', () {
      final late = DateTime(2026, 11, 24, 23);
      expect(nextReviewPhrase(DateTime(2026, 11, 25, 2), late), 'in 3 h');
    });
  });
}
