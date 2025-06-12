import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';

class QuizData {
  // Map of level to their corresponding topic files
  static const Map<int, Map<String, String>> levelTopics = {
    1: {
      'alphabet': 'assets/quiz_data/alphabet.json',
      'vowels': 'assets/quiz_data/vowels.json',
      'word_meaning': 'assets/quiz_data/word_meaning.json',
    },
    2: {
      'body_parts': 'assets/quiz_data/body-parts.json',
      'fruits_vegetables': 'assets/quiz_data/fruits_and_vegetables.json',
    },
  };

  /// Get all questions for a specific level by combining all topics
  static Future<List<QuizQuestion>> getQuestionsForLevel(int level) async {
    print('🔍 QuizData: Attempting to load questions for level $level');
    
    try {
      final Map<String, String>? topics = levelTopics[level];
      if (topics == null) {
        print('❌ QuizData: No topics found for level $level');
        print('📋 Available levels: ${levelTopics.keys.toList()}');
        return [];
      }

      print('📚 QuizData: Found ${topics.length} topics for level $level: ${topics.keys.toList()}');
      
      List<QuizQuestion> allQuestions = [];
      
      // Load questions from all topic files for this level
      for (final entry in topics.entries) {
        final String topic = entry.key;
        final String filePath = entry.value;
        
        print('📖 QuizData: Loading topic "$topic" from $filePath');
        
        try {
          final List<QuizQuestion> topicQuestions = await _loadQuestionsFromFile(filePath);
          allQuestions.addAll(topicQuestions);
          print('✅ QuizData: Loaded ${topicQuestions.length} questions from $topic');
        } catch (e) {
          print('❌ QuizData: Error loading questions from $topic: $e');
        }
      }

      // Shuffle all questions
      final random = Random();
      allQuestions.shuffle(random);
      
      print('🎯 QuizData: Total questions loaded for level $level: ${allQuestions.length}');
      return allQuestions;
    } catch (e) {
      print('💥 QuizData: Critical error loading questions for level $level: $e');
      return [];
    }
  }

  /// Get questions for a specific topic within a level
  static Future<List<QuizQuestion>> getQuestionsForTopic(int level, String topic) async {
    try {
      final Map<String, String>? topics = levelTopics[level];
      if (topics == null || !topics.containsKey(topic)) {
        print('Topic $topic not found for level $level');
        return [];
      }

      final String filePath = topics[topic]!;
      return await _loadQuestionsFromFile(filePath);
    } catch (e) {
      print('Error loading questions for level $level, topic $topic: $e');
      return [];
    }
  }

  /// Get available topics for a level
  static List<Map<String, String>> getTopicsForLevel(int level) {
    final topics = levelTopics[level];
    if (topics == null) return [];
    return topics.entries
        .map((e) => {'key': e.key, 'file': e.value})
        .toList();
  }

  /// Get available levels
  static List<int> getAvailableLevels() {
    return levelTopics.keys.toList()..sort();
  }

  /// Private method to load questions from a single JSON file
  static Future<List<QuizQuestion>> _loadQuestionsFromFile(String filePath) async {
    print('🔧 QuizData: _loadQuestionsFromFile called with: $filePath');
    
    try {
      print('📁 QuizData: Attempting to load string from: $filePath');
      final String jsonString = await rootBundle.loadString(filePath);
      print('📄 QuizData: Successfully loaded JSON string (${jsonString.length} characters)');
      
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      print('🔍 QuizData: JSON decoded successfully. Keys: ${jsonData.keys.toList()}');
      
      // The new format uses 'exercises' instead of 'questions'
      final List<dynamic> exercisesJson = jsonData['exercises'] ?? [];
      print('📝 QuizData: Found ${exercisesJson.length} exercises in the JSON');
      
      if (exercisesJson.isEmpty) {
        print('⚠️ QuizData: Warning - exercises array is empty!');
        return [];
      }
      
      // Convert JSON to QuizQuestion objects
      final questions = exercisesJson.map((exerciseJson) {
        if (exerciseJson is! Map<String, dynamic>) {
          print('⚠️ QuizData: Warning - Invalid exercise format: $exerciseJson');
          return null;
        }
        
        return QuizQuestion(
          tibetanText: exerciseJson['tibetanText'] ?? '',
          options: List<String>.from(exerciseJson['options'] ?? []),
          correctAnswerIndex: exerciseJson['correctAnswerIndex'] ?? 0,
          type: exerciseJson['type'], // Include the exercise type
        );
      }).where((q) => q != null).cast<QuizQuestion>().toList();

      print('✅ QuizData: Successfully converted ${questions.length} exercises to QuizQuestion objects');
      
      // Log the first question for debugging
      if (questions.isNotEmpty) {
        final firstQ = questions.first;
        print('🔍 QuizData: First question - Tibetan: "${firstQ.tibetanText}", Options: ${firstQ.options.length}, Type: ${firstQ.type}');
      }
      
      return questions;
    } catch (e, stackTrace) {
      print('💥 QuizData: Error loading from $filePath: $e');
      print('📚 QuizData: Stack trace: $stackTrace');
      return [];
    }
  }

  /// Load questions for a specific topic file
  static Future<List<QuizQuestion>> getQuestionsForTopicFile(String filePath) async {
    try {
      final jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final List<dynamic> exercisesJson = jsonMap['exercises'] as List<dynamic>;
      return exercisesJson
          .map((exerciseJson) => QuizQuestion.fromJson(exerciseJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading questions from $filePath: $e');
      return [];
    }
  }
} 