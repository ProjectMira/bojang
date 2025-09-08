import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/models/quiz_question.dart';

void main() {
  group('QuizQuestion Model Tests', () {
    const sampleJsonData = {
      'tibetanText': 'ཀ',
      'options': ['ka', 'ga', 'kha'],
      'correctAnswerIndex': 0,
      'type': 'character_recognition'
    };

    test('should create QuizQuestion from valid JSON', () {
      // Arrange & Act
      final question = QuizQuestion.fromJson(sampleJsonData);

      // Assert
      expect(question.tibetanText, equals('ཀ'));
      expect(question.options, equals(['ka', 'ga', 'kha']));
      expect(question.correctAnswerIndex, equals(0));
      expect(question.type, equals('character_recognition'));
    });

    test('should create QuizQuestion without optional type field', () {
      // Arrange
      final jsonWithoutType = Map<String, dynamic>.from(sampleJsonData);
      jsonWithoutType.remove('type');

      // Act
      final question = QuizQuestion.fromJson(jsonWithoutType);

      // Assert
      expect(question.tibetanText, equals('ཀ'));
      expect(question.options, equals(['ka', 'ga', 'kha']));
      expect(question.correctAnswerIndex, equals(0));
      expect(question.type, isNull);
    });

    test('should handle constructor with all parameters', () {
      // Arrange & Act
      final question = QuizQuestion(
        tibetanText: 'ག',
        options: ['ka', 'ga', 'nga'],
        correctAnswerIndex: 1,
        type: 'character_recognition',
      );

      // Assert
      expect(question.tibetanText, equals('ག'));
      expect(question.options, equals(['ka', 'ga', 'nga']));
      expect(question.correctAnswerIndex, equals(1));
      expect(question.type, equals('character_recognition'));
    });

    test('should handle constructor without optional type', () {
      // Arrange & Act
      final question = QuizQuestion(
        tibetanText: 'ང',
        options: ['nya', 'nga', 'cha'],
        correctAnswerIndex: 1,
      );

      // Assert
      expect(question.tibetanText, equals('ང'));
      expect(question.options, equals(['nya', 'nga', 'cha']));
      expect(question.correctAnswerIndex, equals(1));
      expect(question.type, isNull);
    });

    test('should handle empty options list', () {
      // Arrange
      final jsonData = {
        'tibetanText': 'ཀ',
        'options': <String>[],
        'correctAnswerIndex': 0,
      };

      // Act
      final question = QuizQuestion.fromJson(jsonData);

      // Assert
      expect(question.options, isEmpty);
      expect(question.correctAnswerIndex, equals(0));
    });

    test('should handle large options list', () {
      // Arrange
      final manyOptions = List.generate(10, (index) => 'option_$index');
      final jsonData = {
        'tibetanText': 'ཀ',
        'options': manyOptions,
        'correctAnswerIndex': 5,
      };

      // Act
      final question = QuizQuestion.fromJson(jsonData);

      // Assert
      expect(question.options, equals(manyOptions));
      expect(question.options.length, equals(10));
      expect(question.correctAnswerIndex, equals(5));
    });

    test('should handle special characters in Tibetan text', () {
      // Arrange
      const specialTibetanText = 'བོད་ཡིག་སྦྱང་བ།';
      final jsonData = {
        'tibetanText': specialTibetanText,
        'options': ['option1', 'option2'],
        'correctAnswerIndex': 0,
      };

      // Act
      final question = QuizQuestion.fromJson(jsonData);

      // Assert
      expect(question.tibetanText, equals(specialTibetanText));
    });

    group('Edge Cases', () {
      test('should handle negative correctAnswerIndex', () {
        // Arrange
        final jsonData = {
          'tibetanText': 'ཀ',
          'options': ['ka', 'ga'],
          'correctAnswerIndex': -1,
        };

        // Act
        final question = QuizQuestion.fromJson(jsonData);

        // Assert
        expect(question.correctAnswerIndex, equals(-1));
      });

      test('should handle correctAnswerIndex beyond options length', () {
        // Arrange
        final jsonData = {
          'tibetanText': 'ཀ',
          'options': ['ka', 'ga'],
          'correctAnswerIndex': 10,
        };

        // Act
        final question = QuizQuestion.fromJson(jsonData);

        // Assert
        expect(question.correctAnswerIndex, equals(10));
      });

      test('should handle very long Tibetan text', () {
        // Arrange
        final longText = 'ཀ' * 1000;
        final jsonData = {
          'tibetanText': longText,
          'options': ['option'],
          'correctAnswerIndex': 0,
        };

        // Act
        final question = QuizQuestion.fromJson(jsonData);

        // Assert
        expect(question.tibetanText.length, equals(1000));
      });
    });

    group('JSON Validation', () {
      test('should throw when tibetanText is missing', () {
        // Arrange
        final invalidJson = {
          'options': ['ka', 'ga'],
          'correctAnswerIndex': 0,
        };

        // Act & Assert
        expect(
          () => QuizQuestion.fromJson(invalidJson),
          throwsA(isA<TypeError>()),
        );
      });

      test('should throw when options is missing', () {
        // Arrange
        final invalidJson = {
          'tibetanText': 'ཀ',
          'correctAnswerIndex': 0,
        };

        // Act & Assert
        expect(
          () => QuizQuestion.fromJson(invalidJson),
          throwsA(isA<TypeError>()),
        );
      });

      test('should throw when correctAnswerIndex is missing', () {
        // Arrange
        final invalidJson = {
          'tibetanText': 'ཀ',
          'options': ['ka', 'ga'],
        };

        // Act & Assert
        expect(
          () => QuizQuestion.fromJson(invalidJson),
          throwsA(isA<TypeError>()),
        );
      });
    });
  });
}


