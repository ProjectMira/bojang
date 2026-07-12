import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/level_models.dart';
import 'api_service.dart';

/// Loads the learning levels tree: remote API first, falling back to the
/// bundled `assets/quiz_data/levels.json` when the API has nothing (offline,
/// or backend down). Shared by the categories page and the home shortcuts.
class LevelsRepository {
  static Future<List<Level>> loadLevels() async {
    final remoteLevels = await ApiService().getLearningLevels();
    if (remoteLevels != null && remoteLevels.isNotEmpty) {
      return Level.fromApiLevels(remoteLevels);
    }

    final String jsonString = await rootBundle.loadString(
      'assets/quiz_data/levels.json',
    );
    final Map<String, dynamic> jsonData = json.decode(jsonString);

    return (jsonData['levels'] as List)
        .map((level) => Level.fromJson(level))
        .toList();
  }
}
