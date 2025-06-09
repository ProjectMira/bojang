import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';

class QuizData {
  static Future<List<QuizQuestion>> getQuestionsForLevel(int level) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quiz_data/level$level.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> questionsJson = jsonData['questions'];
      
      // Convert JSON to QuizQuestion objects
      final questions = questionsJson.map((questionJson) => QuizQuestion(
        tibetanText: questionJson['tibetanText'],
        options: List<String>.from(questionJson['options']),
        correctAnswerIndex: questionJson['correctAnswerIndex'],
      )).toList();

      // Shuffle the questions
      final random = Random();
      questions.shuffle(random);
      
      return questions;
    } catch (e) {
      print('Error loading questions for level $level: $e');
      return [];
    }
  }
} 