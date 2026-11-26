import 'package:bojang/models/social.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeeklyBoard', () {
    final json = {
      'week_start': '2026-11-23T00:00:00Z',
      'week_end': '2026-11-30T00:00:00Z',
      'entries': [
        {'rank': 1, 'display_name': 'Pema', 'xp': 420, 'is_me': false},
        {'rank': 2, 'display_name': 'Learner 0421', 'xp': 380, 'is_me': true},
      ],
      'me': {
        'rank': 2,
        'xp': 380,
        'visible': true,
        'in_top': true,
        'display_name': 'Learner 0421',
      },
      'total_learners': 2,
    };

    test('parses entries and me', () {
      final board = WeeklyBoard.fromJson(json)!;
      expect(board.entries, hasLength(2));
      expect(board.entries[1].isMe, isTrue);
      expect(board.me.rank, 2);
      expect(board.totalLearners, 2);
      expect(board.ownRowBelow, isNull);
    });

    test('own row is pinned when outside the top 50', () {
      final board = WeeklyBoard.fromJson({
        ...json,
        'me': {
          'rank': 73,
          'xp': 12,
          'visible': true,
          'in_top': false,
          'display_name': 'Tashi',
        },
      })!;
      final row = board.ownRowBelow!;
      expect(row.rank, 73);
      expect(row.isMe, isTrue);
      expect(row.displayName, 'Tashi');
    });

    test('no own row when hidden or without XP', () {
      final board = WeeklyBoard.fromJson({
        ...json,
        'me': {'rank': null, 'xp': 30, 'visible': false, 'in_top': false},
      })!;
      expect(board.ownRowBelow, isNull);
      expect(board.me.visible, isFalse);
    });

    test('time left and reset label', () {
      final board = WeeklyBoard.fromJson(json)!;
      final left = board.timeLeft(DateTime.utc(2026, 11, 27, 19));
      expect(left, const Duration(days: 2, hours: 5));
      expect(weeklyResetLabel(left), 'Resets in 2d 5h');
      expect(weeklyResetLabel(const Duration(hours: 3, minutes: 4)), 'Resets in 3h 4m');
      expect(weeklyResetLabel(Duration.zero), 'Resets in 1m');
      expect(board.timeLeft(DateTime.utc(2027)), Duration.zero);
    });

    test('bad payloads give null', () {
      expect(WeeklyBoard.fromJson(null), isNull);
      expect(WeeklyBoard.fromJson({'entries': []}), isNull);
    });
  });

  group('WeeklyResult', () {
    test('shows once per week and only when placed', () {
      final result = WeeklyResult.fromJson({
        'week_start': '2026-11-16T00:00:00Z',
        'rank': 12,
        'xp': 140,
        'total_learners': 40,
      })!;
      expect(result.weekKey, '2026-11-16');
      expect(result.shouldShow(null), isTrue);
      expect(result.shouldShow('2026-11-09'), isTrue);
      expect(result.shouldShow('2026-11-16'), isFalse);
      final unplaced = WeeklyResult.fromJson({
        'week_start': '2026-11-16T00:00:00Z',
        'rank': null,
        'xp': 0,
      })!;
      expect(unplaced.shouldShow(null), isFalse);
    });
  });

  group('Family', () {
    test('parses members and fullness', () {
      final state = FamilyState.fromJson({
        'members': [
          {
            'link_id': 'l1',
            'display_name': 'Ama',
            'streak': 9,
            'shared_streak': 4,
            'practised_today': true,
            'you_practised_today': true,
            'can_nudge': false,
            'nudged_today': false,
          },
        ],
        'max_members': 1,
      })!;
      expect(state.members.single.sharedStreak, 4);
      expect(state.members.single.bothDoneToday, isTrue);
      expect(state.isFull, isTrue);
      expect(FamilyState.fromJson({'members': []})!.maxMembers, 5);
    });

    test('invite codes normalize', () {
      expect(normalizeInviteCode(' k7qh-m2xp '), 'K7QHM2XP');
      expect(normalizeInviteCode('K7QH M2XP'), 'K7QHM2XP');
      expect(normalizeInviteCode('abc'), isNull);
      expect(FamilyInvite.fromJson({'code': 'K7QH-M2XP'})!.code, 'K7QH-M2XP');
      expect(FamilyInvite.fromJson({'code': ''}), isNull);
    });

    test('invite errors map from the server', () {
      expect(inviteErrorFrom(null, null), InviteError.offline);
      expect(inviteErrorFrom(404, {'error': 'invalid_code'}), InviteError.invalid);
      expect(inviteErrorFrom(409, {'error': 'own_code'}), InviteError.ownCode);
      expect(inviteErrorFrom(409, {'error': 'already_linked'}), InviteError.alreadyLinked);
      expect(inviteErrorFrom(409, {'error': 'family_full'}), InviteError.full);
      expect(inviteErrorFrom(409, {'error': 'their_family_full'}), InviteError.theirFull);
      for (final e in InviteError.values) {
        expect(inviteErrorMessage(e), isNotEmpty);
      }
    });
  });

  group('Photos and safety', () {
    final json = {
      'week_start': '2026-11-23T00:00:00Z',
      'week_end': '2026-11-30T00:00:00Z',
      'entries': [
        {
          'rank': 1,
          'display_name': 'Pema',
          'xp': 420,
          'avatar': 'conch:gold',
          'photo_url': 'https://storage.example/profile-photos/a.jpg',
          'token': 'tok-pema',
        },
        {
          'rank': 2,
          'display_name': 'Tashi',
          'xp': 380,
          'is_me': true,
          'avatar': 'yak_love:red',
          'token': 'tok-me',
        },
        {'rank': 3, 'display_name': 'Dolma', 'xp': 300, 'token': 'tok-dolma'},
      ],
      'me': {
        'rank': 2,
        'xp': 380,
        'in_top': true,
        'display_name': 'Tashi',
        'avatar': 'yak_love:red',
        'photo_url': null,
        'photo_hidden': true,
      },
      'total_learners': 3,
    };

    test('entries carry photo, avatar and an opaque token', () {
      final board = WeeklyBoard.fromJson(json)!;
      final pema = board.entries.first;
      expect(pema.photoUrl, 'https://storage.example/profile-photos/a.jpg');
      expect(pema.avatar, 'conch:gold');
      expect(pema.token, 'tok-pema');
      expect(pema.canReport, isTrue);
      expect(board.entries[2].photoUrl, isNull);
      expect(board.me.photoHidden, isTrue);
    });

    test('only https photo URLs are used', () {
      final e = WeeklyEntry.fromJson({
        'rank': 1,
        'display_name': 'X',
        'xp': 1,
        'photo_url': 'http://insecure.example/p.jpg',
      });
      expect(e.photoUrl, isNull);
    });

    test('the learner cannot report themselves', () {
      final board = WeeklyBoard.fromJson(json)!;
      expect(board.ownEntry!.displayName, 'Tashi');
      expect(board.ownEntry!.canReport, isFalse);
      expect(board.ownRowBelow, isNull);
    });

    test('hiding drops one entry and keeps everyone\'s rank', () {
      final board = WeeklyBoard.fromJson(json)!.without('tok-pema');
      expect(board.entries.map((e) => e.rank), [2, 3]);
      expect(board.totalLearners, 3);
      expect(WeeklyBoard.fromJson(json)!.without('').entries, hasLength(3));
    });

    test('pinned row outside the top 50 carries my photo', () {
      final board =
          WeeklyBoard.fromJson({
            ...json,
            'me': {
              'rank': 73,
              'xp': 12,
              'in_top': false,
              'display_name': 'Tashi',
              'photo_url': 'https://storage.example/profile-photos/me.jpg',
            },
          })!;
      final row = board.ownRowBelow!;
      expect(row.photoUrl, 'https://storage.example/profile-photos/me.jpg');
      expect(row.canReport, isFalse);
    });

    test('report reasons match the server', () {
      expect(ReportReason.values.map((r) => r.key), [
        'inappropriate',
        'offensive',
        'impersonation',
        'spam',
        'other',
      ]);
    });
  });

  group('Board place', () {
    test('entries and me carry the city line when shown', () {
      final e = WeeklyEntry.fromJson({
        'rank': 1,
        'display_name': 'Pema',
        'xp': 10,
        'place': 'Dharamsala, India',
        'token': 't',
      });
      expect(e.place, 'Dharamsala, India');
      expect(
        WeeklyEntry.fromJson({'rank': 1, 'display_name': 'X', 'xp': 1, 'place': '  '}).place,
        isNull,
      );
      final board = WeeklyBoard.fromJson({
        'week_start': '2026-11-23T00:00:00Z',
        'week_end': '2026-11-30T00:00:00Z',
        'entries': [],
        'me': {'rank': 80, 'xp': 5, 'in_top': false, 'display_name': 'T', 'place': 'Delhi, India'},
      })!;
      expect(board.ownRowBelow!.place, 'Delhi, India');
    });
  });
}
