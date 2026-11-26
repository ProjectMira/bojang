import 'package:bojang/models/firebase_event_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eventName', () {
    test('keeps ordinary snake_case names', () {
      expect(
        FirebaseEventRules.eventName('lesson_completed'),
        'lesson_completed',
      );
    });

    test(r'skips PostHog $ events', () {
      expect(FirebaseEventRules.eventName(r'$screen'), isNull);
      expect(FirebaseEventRules.eventName(r'$exception'), isNull);
    });

    test('renames reserved names and prefixes', () {
      expect(FirebaseEventRules.eventName('error'), 'bj_error');
      expect(FirebaseEventRules.eventName('session_start'), 'bj_session_start');
      expect(
        FirebaseEventRules.eventName('firebase_thing'),
        'bj_firebase_thing',
      );
    });

    test('replaces invalid characters, starts with a letter, max 40', () {
      expect(FirebaseEventRules.eventName('9-lives.x'), 'lives_x');
      final long = FirebaseEventRules.eventName('a' * 60)!;
      expect(long.length, 40);
      expect(FirebaseEventRules.eventName('___'), isNull);
    });
  });

  group('params', () {
    test('drops nulls and PII, maps bools, cuts strings', () {
      final p = FirebaseEventRules.params({
        'score': 7,
        'accuracy': 0.5,
        'correct': true,
        'skipped': false,
        'missing': null,
        'email': 'a@b.c',
        'user_email': 'a@b.c',
        'name': 'Tashi',
        'approx_lat': 27.7,
        'text': 'x' * 150,
        'list': [1, 2],
      });
      expect(p, {
        'score': 7,
        'accuracy': 0.5,
        'correct': 1,
        'skipped': 0,
        'text': 'x' * 100,
        'list': '[1,2]',
      });
    });

    test('at most 25 parameters', () {
      final p = FirebaseEventRules.params({
        for (var i = 0; i < 40; i++) 'p$i': i,
      });
      expect(p.length, 25);
      expect(p.containsKey('p0'), isTrue);
      expect(p.containsKey('p30'), isFalse);
    });

    test('non-finite numbers become strings', () {
      expect(FirebaseEventRules.params({'x': double.nan})['x'], 'NaN');
    });
  });

  group('userProperties', () {
    test('strings of at most 36, skips long, reserved and PII names', () {
      final p = FirebaseEventRules.userProperties({
        'current_streak': 12,
        'dark_mode': true,
        'reminder_time': '08:30',
        'voice': 'v' * 50,
        'a_property_name_longer_than_24': 1,
        'gender': 'x',
        'name': 'Tashi',
        'avatar': 'yak',
        'location_approx_lat': 27.7,
        'cleared': null,
      });
      expect(p, {
        'current_streak': '12',
        'dark_mode': '1',
        'reminder_time': '08:30',
        'voice': 'v' * 36,
        'cleared': null,
      });
    });
  });
}
