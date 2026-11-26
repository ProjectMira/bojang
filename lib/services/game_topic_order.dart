import 'package:shared_preferences/shared_preferences.dart';

import 'beginner.dart';

/// The order topics are offered in the games: the ones you played lately
/// first, then the rest in course order, with Tibetan Basics (the alphabet)
/// last once you are past being a beginner. Beginners keep course order, so
/// the alphabet stays on top for them.
class GameTopicOrder {
  GameTopicOrder._();

  static const String recentKey = 'game_recent_topics';
  static const int keep = 6;

  static bool isBasics(String id) =>
      id.startsWith('basics-') || id.startsWith('script-');

  /// Remembers [id] as the most recently played topic.
  static Future<void> played(String? id) async {
    if (id == null || id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(recentKey) ?? <String>[];
      list
        ..remove(id)
        ..insert(0, id);
      await prefs.setStringList(recentKey, list.take(keep).toList());
    } catch (_) {}
  }

  static Future<List<String>> recent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(recentKey) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// [items] in the order to show them. Pure, for tests: pass [recentIds]
  /// and [beginner] directly.
  static List<T> sort<T>(
    List<T> items,
    String Function(T) idOf, {
    required List<String> recentIds,
    required bool beginner,
  }) {
    int rankOf(T item) {
      final id = idOf(item);
      final r = recentIds.indexOf(id);
      if (r >= 0) return r; // recently played, most recent first
      if (!beginner && isBasics(id)) return 2000; // alphabet at the end
      return 1000; // everything else, in course order
    }

    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final c = rankOf(a.$2).compareTo(rankOf(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// [sort] with what this device knows.
  static Future<List<T>> apply<T>(List<T> items, String Function(T) idOf) async {
    final recentIds = await recent();
    final beginner = await Beginner.now();
    return sort(items, idOf, recentIds: recentIds, beginner: beginner);
  }
}
