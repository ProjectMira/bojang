class Category {
  final String id;
  final String name;
  final String? tibetanName;
  final String? description;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    this.tibetanName,
    this.description,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      tibetanName: json['tibetan_name'] as String?,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tibetan_name': tibetanName,
      'description': description,
      'icon_url': iconUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? tibetanName,
    String? description,
    String? iconUrl,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      tibetanName: tibetanName ?? this.tibetanName,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum Difficulty { beginner, intermediate, advanced }

class Level {
  final String id;
  final String categoryId;
  final int levelNumber;
  final String name;
  final String? description;
  final Difficulty difficulty;
  final int unlockRequirement;
  final bool isActive;
  final DateTime createdAt;

  Level({
    required this.id,
    required this.categoryId,
    required this.levelNumber,
    required this.name,
    this.description,
    this.difficulty = Difficulty.beginner,
    this.unlockRequirement = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      levelNumber: json['level_number'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      difficulty: _parseDifficulty(json['difficulty'] as String?),
      unlockRequirement: json['unlock_requirement'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'level_number': levelNumber,
      'name': name,
      'description': description,
      'difficulty': _difficultyToString(difficulty),
      'unlock_requirement': unlockRequirement,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static Difficulty _parseDifficulty(String? difficulty) {
    switch (difficulty) {
      case 'intermediate':
        return Difficulty.intermediate;
      case 'advanced':
        return Difficulty.advanced;
      default:
        return Difficulty.beginner;
    }
  }

  static String _difficultyToString(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'beginner';
      case Difficulty.intermediate:
        return 'intermediate';
      case Difficulty.advanced:
        return 'advanced';
    }
  }

  Level copyWith({
    String? id,
    String? categoryId,
    int? levelNumber,
    String? name,
    String? description,
    Difficulty? difficulty,
    int? unlockRequirement,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Level(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      levelNumber: levelNumber ?? this.levelNumber,
      name: name ?? this.name,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      unlockRequirement: unlockRequirement ?? this.unlockRequirement,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
