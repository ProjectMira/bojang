import 'dart:convert';

class Sublevel {
  final String level;
  final String name;
  final String path;

  Sublevel({
    required this.level,
    required this.name,
    required this.path,
  });

  factory Sublevel.fromJson(Map<String, dynamic> json) {
    return Sublevel(
      level: json['level'].toString(),
      name: json['name'] ?? '',
      path: json['path'] ?? '',
    );
  }
}

class Level {
  final int level;
  final String title;
  final List<Sublevel> sublevels;

  Level({
    required this.level,
    required this.title,
    required this.sublevels,
  });

  factory Level.fromJson(Map<String, dynamic> json) {
    return Level(
      level: json['level'] ?? 0,
      title: json['title'] ?? '',
      sublevels: (json['sublevels'] as List?)
          ?.map((sublevel) => Sublevel.fromJson(sublevel))
          .toList() ?? [],
    );
  }
} 