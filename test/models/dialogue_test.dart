import 'package:bojang/models/dialogue.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> dialogueJson({bool session = true}) => {
  'id': 'dlg-greetings',
  'type': 'dialogue',
  'title': 'Saying hello',
  'title_bo': 'བཀྲ་ཤིས་བདེ་ལེགས།',
  'description': 'Pema and Tashi greet each other.',
  'unit_id': 'tibetan-basics',
  'after_level_id': 'basics-greetings',
  'status': 'draft',
  'speakers': [
    {
      'id': 'pema',
      'name': 'Pema',
      'name_bo': 'པདྨ།',
      'voice': 'lhasa_female',
      'shape': 'circle',
      'color': 'coral',
    },
    {
      'id': 'tashi',
      'name': 'Tashi',
      'name_bo': 'བཀྲ་ཤིས།',
      'voice': 'kham_male',
      'shape': 'rounded_square',
      'color': 'teal',
    },
  ],
  'lines': [
    {
      'speaker': 'pema',
      'voice': 'lhasa_female',
      'tibetan': 'བཀྲ་ཤིས་བདེ་ལེགས།',
      'phonetic': 'trashi delek',
      'wylie': 'bkra shis bde legs',
      'english': 'Hello!',
      'audio_urls': {'lhasa_female': 'https://x/01.mp3'},
    },
    {
      'speaker': 'tashi',
      'voice': 'kham_male',
      'tibetan': 'ཐུགས་རྗེ་ཆེ།',
      'phonetic': 'tukjé ché',
      'wylie': 'thugs rje che',
      'english': 'Thank you.',
      'audio_urls': {},
    },
  ],
  'questions': [
    {
      'id': 'q1',
      'prompt': 'How is Pema?',
      'options': [
        {'id': 'q1-a', 'text': 'She is tired'},
        {'id': 'q1-b', 'text': 'She is well'},
      ],
      'correct_option_id': 'q1-b',
    },
    {
      'id': 'q-empty',
      'prompt': 'Broken',
      'options': [],
      'correct_option_id': '',
    },
  ],
  'session':
      session
          ? {
            'session_id': 's-1',
            'level_id': 'basics-greetings',
            'total_questions': 1,
          }
          : null,
};

void main() {
  test('parses a dialogue payload', () {
    final d = Dialogue.fromJson(dialogueJson());
    expect(d.id, 'dlg-greetings');
    expect(d.status, 'draft');
    expect(d.speakers.map((s) => s.voice), ['lhasa_female', 'kham_male']);
    expect(d.lines.first.romanisation.phonetic, 'trashi delek');
    expect(d.lines.first.romanisation.wylie, 'bkra shis bde legs');
    expect(d.lines.first.audioUrl, 'https://x/01.mp3');
    expect(d.lines.last.audioUrl, isNull);
    expect(d.hasAudio, isFalse);
    expect(d.audioUrls, ['https://x/01.mp3']);
    // Questions without options are dropped.
    expect(d.questions.map((q) => q.id), ['q1']);
    expect(d.questions.first.correctOption?.text, 'She is well');
    expect(d.session?.levelId, 'basics-greetings');
  });

  test('speaker sides and placeholders', () {
    final d = Dialogue.fromJson(dialogueJson());
    expect(d.isLeading(d.lines[0]), isTrue);
    expect(d.isLeading(d.lines[1]), isFalse);
    expect(d.speakerOf(d.lines[1]).initial, 'T');
    final stranger = const DialogueLine(speaker: 'dawa', tibetan: 'ཀ');
    expect(d.speakerOf(stranger).name, 'dawa');
  });

  test('no session for a signed-out learner', () {
    expect(Dialogue.fromJson(dialogueJson(session: false)).session, isNull);
  });

  test('builds the /progress/complete body', () {
    final d = Dialogue.fromJson(dialogueJson());
    final body = dialogueCompletion(
      session: d.session!,
      answers: const [
        DialogueAnswer(
          questionId: 'q1',
          optionId: 'q1-a',
          correct: false,
          ms: 900,
        ),
      ],
      localDate: '2026-11-23',
      timeTakenSeconds: 30,
    );
    expect(body['session_id'], 's-1');
    expect(body['level_id'], 'basics-greetings');
    expect(body['correct_answers'], 0);
    expect(body['total_questions'], 1);
    expect(body['answers'], [
      {'exercise_id': 'q1', 'answer': 'q1-a', 'correct': false, 'ms': 900},
    ]);
  });
}
