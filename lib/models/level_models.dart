class Sublevel {
  final String level;
  final String name;
  final String path;
  final String? description;
  final bool isLocked;
  final int requiredXp;

  /// Number of words available for this topic. -1 means unknown
  /// (e.g. bundled asset lessons that don't report counts).
  final int wordCount;
  final int sentenceCount;

  Sublevel({
    required this.level,
    required this.name,
    required this.path,
    this.description,
    this.isLocked = false,
    this.requiredXp = 0,
    this.wordCount = -1,
    this.sentenceCount = -1,
  });

  bool get hasContent => wordCount != 0 || sentenceCount != 0;

  factory Sublevel.fromJson(Map<String, dynamic> json) {
    return Sublevel(
      level: json['level'].toString(),
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      description: json['description'] as String?,
      isLocked: json['is_locked'] as bool? ?? false,
      requiredXp: json['required_xp'] as int? ?? 0,
    );
  }

  factory Sublevel.fromApiLevel(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    return Sublevel(
      level: (json['order'] ?? '').toString(),
      name: (json['name'] ?? id).toString(),
      path: 'api://level/$id',
      description: json['description'] as String?,
      isLocked: json['is_locked'] as bool? ?? false,
      requiredXp: json['required_xp'] as int? ?? 0,
      wordCount: json['word_count'] as int? ?? -1,
      sentenceCount: json['sentence_count'] as int? ?? -1,
    );
  }
}

class Level {
  final int level;
  final String title;
  final List<Sublevel> sublevels;

  Level({required this.level, required this.title, required this.sublevels});

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      level: json['level'] ?? 0,
      title: json['title'] ?? '',
      sublevels:
          (json['sublevels'] as List?)
              ?.map((sublevel) => Sublevel.fromJson(sublevel))
              .toList() ??
          [],
    );
  }

  static List<Level> fromApiLevels(List<Map<String, dynamic>> apiLevels) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in apiLevels) {
      // Skip topics with no content yet — sessions for them would fall back
      // to unrelated words.
      final wordCount = item['word_count'] as int? ?? -1;
      final sentenceCount = item['sentence_count'] as int? ?? -1;
      if (wordCount == 0 && sentenceCount == 0) continue;
      final unit = (item['unit'] ?? 'Learning Path').toString();
      grouped.putIfAbsent(unit, () => []).add(item);
    }

    var index = 1;
    return grouped.entries.map((entry) {
      entry.value.sort((a, b) {
        final aOrder = a['order'] as int? ?? 0;
        final bOrder = b['order'] as int? ?? 0;
        return aOrder.compareTo(bOrder);
      });
      final title = _formatUnitName(entry.key);
      return Level(
        level: index++,
        title: title,
        sublevels: entry.value.map(Sublevel.fromApiLevel).toList(),
      );
    }).toList();
  }

  static String _formatUnitName(String unit) {
    if (unit == 'vocab-categories') return 'Vocabulary';
    return unit
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
