import '../models/game_word.dart';
import 'api_service.dart';

/// A vocabulary topic a game can be played with.
class GameTopic {
  final String id;
  final String name;
  final int wordCount;
  final bool hasImages;

  const GameTopic({
    required this.id,
    required this.name,
    required this.wordCount,
    required this.hasImages,
  });
}

/// Where the games get their topics and words. A class rather than static
/// helpers so tests can hand a game a fixed word list.
class GameWordsRepository {
  const GameWordsRepository();

  Future<List<GameTopic>> loadTopics() async {
    final levels = await ApiService().getLearningLevels();
    return [
      for (final level in levels ?? const <Map<String, dynamic>>[])
        GameTopic(
          id: (level['id'] ?? '').toString(),
          name: (level['name'] ?? '').toString(),
          wordCount: level['word_count'] as int? ?? 0,
          hasImages: level['has_images'] == true,
        ),
    ].where((topic) => topic.id.isNotEmpty && topic.wordCount > 0).toList();
  }

  /// The topic's words, each with its picture and recordings.
  ///
  /// The backend has no "words of a level" endpoint that carries media, but
  /// every `memory_match` exercise holds eight full word cards, so a session
  /// of them is merged into one list (17 of 17 words for a small topic, a
  /// fresh sample of a few dozen for a large one).
  Future<List<GameWord>> loadWords(String topicId) async {
    final session = await ApiService().getLearningSession(
      levelId: topicId,
      numQuestions: 10,
      exerciseTypes: const ['memory_match'],
    );
    final exercises = List<Map<String, dynamic>>.from(
      session?['exercises'] as List<dynamic>? ?? const [],
    );
    final words = <GameWord>[];
    for (final exercise in exercises) {
      final cards = exercise['cards'];
      if (cards is! List) continue;
      for (final card in cards) {
        if (card is! Map) continue;
        final word = GameWord.fromCard(Map<String, dynamic>.from(card));
        if (word != null) words.add(word);
      }
    }
    return GameWord.distinct(words);
  }
}
