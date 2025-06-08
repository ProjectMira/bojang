import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';

class QuizData {
  static Future<List<QuizQuestion>> getQuestionsForLevel(int level) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quiz_data/level$level.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> questionsJson = jsonData['questions'];
      
      return questionsJson.map((questionJson) => QuizQuestion(
        tibetanText: questionJson['tibetanText'],
        options: List<String>.from(questionJson['options']),
        correctAnswerIndex: questionJson['correctAnswerIndex'],
      )).toList();
    } catch (e) {
      print('Error loading questions for level $level: $e');
      return [];
    }
  }
} 