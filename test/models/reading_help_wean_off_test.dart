import 'dart:convert';

import 'package:bojang/models/romanisation.dart';
import 'package:bojang/services/reading_help.dart';
import 'package:bojang/services/user_kv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// user_kv that accepts every write (version checks are not under test).
Future<http.Response?> _okKv(
  String method,
  String endpoint, {
  Object? body,
}) async {
  if (method == 'GET') return http.Response('{"items":{}}', 200);
  final items = <String, Object?>{
    for (final item in (body as Map)['items'] as List)
      item['key'] as String: {'value': item['value'], 'version': 1},
  };
  return http.Response(jsonEncode({'items': items}), 200);
}

void main() {
  group('WeanOffPolicy (plan #7)', () {
    test('right answers with help shown build the run; a miss resets it', () {
      var run = 0;
      for (var i = 0; i < 5; i++) {
        run = WeanOffPolicy.nextRun(run, correct: true, helpShown: true);
      }
      expect(run, 5);
      expect(WeanOffPolicy.nextRun(run, correct: true, helpShown: false), 5);
      expect(WeanOffPolicy.nextRun(run, correct: false, helpShown: true), 0);
    });

    test('suggests at 20, once, and never with help off', () {
      bool s(
        int run, {
        bool shown = false,
        TransliterationMode mode = TransliterationMode.phonetics,
      }) => WeanOffPolicy.shouldSuggest(
        run: run,
        alreadyShown: shown,
        mode: mode,
      );
      expect(s(19), isFalse);
      expect(s(20), isTrue);
      expect(s(25, shown: true), isFalse);
      expect(s(25, mode: TransliterationMode.off), isFalse);
    });
  });

  group('ReadingHelp', () {
    const word = Romanisation(
      phonetic: 'trashi delek',
      wylie: 'bkra shis bde legs',
    );
    late ReadingHelp help;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      help = ReadingHelp(
        tips: SeenTips(UserKv(transport: _okKv, uid: () => 't')),
      );
      await help.load();
    });

    test('a word is known after two right answers', () async {
      await help.recordAnswer(
        word,
        correct: true,
        mode: TransliterationMode.both,
      );
      expect(help.isKnown(word), isFalse);
      await help.recordAnswer(
        word,
        correct: false,
        mode: TransliterationMode.both,
      );
      await help.recordAnswer(
        word,
        correct: true,
        mode: TransliterationMode.both,
      );
      expect(help.isKnown(word), isTrue);
      expect(help.hides(word), isFalse, reason: '"new words only" is off');
      await help.setNewWordsOnly(true);
      expect(help.hides(word), isTrue);
      expect(
        help.hides(const Romanisation(phonetic: 'chu', wylie: 'chu')),
        isFalse,
      );
    });

    test('20 right in a row with help on makes the suggestion due', () async {
      for (var i = 0; i < 19; i++) {
        await help.recordAnswer(
          Romanisation(phonetic: 'w$i', wylie: 'w$i'),
          correct: true,
          mode: TransliterationMode.phonetics,
        );
      }
      expect(help.suggestionDue, isFalse);
      await help.recordAnswer(
        const Romanisation(phonetic: 'last', wylie: 'last'),
        correct: true,
        mode: TransliterationMode.phonetics,
      );
      expect(help.run, 20);
      expect(help.suggestionDue, isTrue);
    });

    test('answers with the reading hidden do not count', () async {
      for (var i = 0; i < 25; i++) {
        await help.recordAnswer(
          Romanisation(phonetic: 'k$i'),
          correct: true,
          mode: TransliterationMode.phonetics,
          hiddenUntilAnswered: true,
        );
      }
      expect(help.run, 0);
      for (var i = 0; i < 25; i++) {
        await help.recordAnswer(
          Romanisation(phonetic: 'o$i'),
          correct: true,
          mode: TransliterationMode.off,
        );
      }
      expect(help.suggestionDue, isFalse);
    });

    test('a tip already seen in user_kv tips is not suggested again', () async {
      final kv = UserKv(transport: _okKv, uid: () => 'seen');
      await SeenTips(kv).markSeen(WeanOffPolicy.tipKey);
      final seen = ReadingHelp(tips: SeenTips(kv));
      await seen.load();
      for (var i = 0; i < 20; i++) {
        await seen.recordAnswer(
          Romanisation(phonetic: 's$i'),
          correct: true,
          mode: TransliterationMode.phonetics,
        );
      }
      expect(seen.suggestionDue, isFalse);
    });
  });
}
