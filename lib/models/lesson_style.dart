import 'quiz_question.dart';

/// How a lesson's questions are presented. Chosen once (Settings, or the
/// tune button inside a lesson) and remembered, so opening a topic never
/// stops to ask.
enum LessonStyle {
  /// A blend of every question kind below. The default.
  mixed,

  /// See a picture, pick the Tibetan word.
  pictures,

  /// See a Tibetan word, pick its English meaning.
  words,

  /// Hear a Tibetan word, pick its English meaning.
  listening;

  static LessonStyle fromId(String? id) {
    for (final style in LessonStyle.values) {
      if (style.name == id) return style;
    }
    return LessonStyle.mixed;
  }

  String get title => switch (this) {
    LessonStyle.mixed => 'Mixed',
    LessonStyle.pictures => 'Pictures',
    LessonStyle.words => 'Words',
    LessonStyle.listening => 'Listening',
  };

  String get subtitle => switch (this) {
    LessonStyle.mixed => 'Pictures, listening and words in one lesson',
    LessonStyle.pictures => 'See a picture, pick the Tibetan word',
    LessonStyle.words => 'See a Tibetan word, pick its meaning',
    LessonStyle.listening => 'Hear a Tibetan word, pick its meaning',
  };

  /// Exercise types to request from the backend for this style.
  List<String> get exerciseTypes => switch (this) {
    LessonStyle.mixed => const ['multiple_choice', 'picture_choice'],
    LessonStyle.pictures => const ['picture_choice'],
    LessonStyle.words => const ['multiple_choice'],
    LessonStyle.listening => const ['multiple_choice'],
  };

  /// Turns the backend's two exercise types into this style's question
  /// kinds. Listening and "say it in Tibetan" questions are derived on the
  /// device from the same payloads, so they need no backend support.
  ///
  /// Questions that cannot be converted (a word with no recording, a
  /// picture question with no English gloss) are kept as they were, so a
  /// lesson never loses questions.
  List<QuizQuestion> arrange(List<QuizQuestion> questions) {
    switch (this) {
      case LessonStyle.words:
      case LessonStyle.pictures:
        return questions;
      case LessonStyle.listening:
        return [for (final q in questions) q.asListening() ?? q];
      case LessonStyle.mixed:
        var wordQuestions = 0;
        var pictureQuestions = 0;
        final arranged = <QuizQuestion>[];
        for (final q in questions) {
          if (q.type == QuizQuestion.pictureChoice) {
            // Every third picture question drops the picture and asks for
            // the Tibetan word from its English meaning instead.
            pictureQuestions++;
            final reverse = pictureQuestions % 3 == 0 ? q.asReverse() : null;
            arranged.add(reverse ?? q);
          } else {
            // Every second word question becomes a listening question.
            wordQuestions++;
            final listening = wordQuestions.isEven ? q.asListening() : null;
            arranged.add(listening ?? q);
          }
        }
        return arranged;
    }
  }
}
