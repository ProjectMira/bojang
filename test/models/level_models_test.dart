import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/models/level_models.dart';

void main() {
  group('Sublevel Model Tests', () {
    const sampleSublevelJson = {
      'level': '1.1',
      'name': 'Alphabet',
      'path': 'assets/quiz_data/level-1/alphabet.json'
    };

    test('should create Sublevel from valid JSON', () {
      // Arrange & Act
      final sublevel = Sublevel.fromJson(sampleSublevelJson);

      // Assert
      expect(sublevel.level, equals('1.1'));
      expect(sublevel.name, equals('Alphabet'));
      expect(sublevel.path, equals('assets/quiz_data/level-1/alphabet.json'));
    });

    test('should handle constructor with all parameters', () {
      // Arrange & Act
      final sublevel = Sublevel(
        level: '2.5',
        name: 'Advanced Grammar',
        path: 'assets/quiz_data/level-2/advanced-grammar.json',
      );

      // Assert
      expect(sublevel.level, equals('2.5'));
      expect(sublevel.name, equals('Advanced Grammar'));
      expect(sublevel.path, equals('assets/quiz_data/level-2/advanced-grammar.json'));
    });

    test('should handle missing name field with empty string default', () {
      // Arrange
      final jsonWithoutName = {
        'level': '1.2',
        'path': 'assets/quiz_data/level-1/vowels.json'
      };

      // Act
      final sublevel = Sublevel.fromJson(jsonWithoutName);

      // Assert
      expect(sublevel.level, equals('1.2'));
      expect(sublevel.name, equals(''));
      expect(sublevel.path, equals('assets/quiz_data/level-1/vowels.json'));
    });

    test('should handle missing path field with empty string default', () {
      // Arrange
      final jsonWithoutPath = {
        'level': '1.3',
        'name': 'Numbers'
      };

      // Act
      final sublevel = Sublevel.fromJson(jsonWithoutPath);

      // Assert
      expect(sublevel.level, equals('1.3'));
      expect(sublevel.name, equals('Numbers'));
      expect(sublevel.path, equals(''));
    });

    test('should convert numeric level to string', () {
      // Arrange
      final jsonWithNumericLevel = {
        'level': 1,
        'name': 'Beginner',
        'path': 'assets/quiz_data/level-1/beginner.json'
      };

      // Act
      final sublevel = Sublevel.fromJson(jsonWithNumericLevel);

      // Assert
      expect(sublevel.level, equals('1'));
    });

    test('should handle null values gracefully', () {
      // Arrange
      final jsonWithNulls = {
        'level': null,
        'name': null,
        'path': null
      };

      // Act
      final sublevel = Sublevel.fromJson(jsonWithNulls);

      // Assert
      expect(sublevel.level, equals('null'));
      expect(sublevel.name, equals(''));
      expect(sublevel.path, equals(''));
    });
  });

  group('Level Model Tests', () {
    const sampleLevelJson = {
      'level': 1,
      'title': 'Beginner',
      'sublevels': [
        {
          'level': '1.1',
          'name': 'Alphabet',
          'path': 'assets/quiz_data/level-1/alphabet.json'
        },
        {
          'level': '1.2',
          'name': 'Vowels',
          'path': 'assets/quiz_data/level-1/vowels.json'
        }
      ]
    };

    test('should create Level from valid JSON', () {
      // Arrange & Act
      final level = Level.fromJson(sampleLevelJson);

      // Assert
      expect(level.level, equals(1));
      expect(level.title, equals('Beginner'));
      expect(level.sublevels, hasLength(2));
      expect(level.sublevels[0].name, equals('Alphabet'));
      expect(level.sublevels[1].name, equals('Vowels'));
    });

    test('should handle constructor with all parameters', () {
      // Arrange
      final sublevels = [
        Sublevel(level: '3.1', name: 'Advanced', path: 'path1.json'),
        Sublevel(level: '3.2', name: 'Expert', path: 'path2.json'),
      ];

      // Act
      final level = Level(
        level: 3,
        title: 'Advanced Level',
        sublevels: sublevels,
      );

      // Assert
      expect(level.level, equals(3));
      expect(level.title, equals('Advanced Level'));
      expect(level.sublevels, equals(sublevels));
      expect(level.sublevels, hasLength(2));
    });

    test('should handle missing level field with 0 default', () {
      // Arrange
      final jsonWithoutLevel = {
        'title': 'Intermediate',
        'sublevels': []
      };

      // Act
      final level = Level.fromJson(jsonWithoutLevel);

      // Assert
      expect(level.level, equals(0));
      expect(level.title, equals('Intermediate'));
      expect(level.sublevels, isEmpty);
    });

    test('should handle missing title field with empty string default', () {
      // Arrange
      final jsonWithoutTitle = {
        'level': 2,
        'sublevels': []
      };

      // Act
      final level = Level.fromJson(jsonWithoutTitle);

      // Assert
      expect(level.level, equals(2));
      expect(level.title, equals(''));
      expect(level.sublevels, isEmpty);
    });

    test('should handle missing sublevels field with empty list default', () {
      // Arrange
      final jsonWithoutSublevels = {
        'level': 1,
        'title': 'Beginner'
      };

      // Act
      final level = Level.fromJson(jsonWithoutSublevels);

      // Assert
      expect(level.level, equals(1));
      expect(level.title, equals('Beginner'));
      expect(level.sublevels, isEmpty);
    });

    test('should handle null sublevels with empty list default', () {
      // Arrange
      final jsonWithNullSublevels = {
        'level': 1,
        'title': 'Beginner',
        'sublevels': null
      };

      // Act
      final level = Level.fromJson(jsonWithNullSublevels);

      // Assert
      expect(level.level, equals(1));
      expect(level.title, equals('Beginner'));
      expect(level.sublevels, isEmpty);
    });

    test('should handle empty sublevels list', () {
      // Arrange
      final jsonWithEmptySublevels = {
        'level': 4,
        'title': 'Expert',
        'sublevels': []
      };

      // Act
      final level = Level.fromJson(jsonWithEmptySublevels);

      // Assert
      expect(level.level, equals(4));
      expect(level.title, equals('Expert'));
      expect(level.sublevels, isEmpty);
    });

    test('should handle large number of sublevels', () {
      // Arrange
      final manySublevels = List.generate(50, (index) => {
        'level': '1.${index + 1}',
        'name': 'Sublevel ${index + 1}',
        'path': 'assets/path${index + 1}.json'
      });
      final jsonWithManySublevels = {
        'level': 1,
        'title': 'Comprehensive Level',
        'sublevels': manySublevels
      };

      // Act
      final level = Level.fromJson(jsonWithManySublevels);

      // Assert
      expect(level.sublevels, hasLength(50));
      expect(level.sublevels.first.name, equals('Sublevel 1'));
      expect(level.sublevels.last.name, equals('Sublevel 50'));
    });

    group('Edge Cases', () {
      test('should handle negative level number', () {
        // Arrange
        final jsonWithNegativeLevel = {
          'level': -1,
          'title': 'Test Level',
          'sublevels': []
        };

        // Act
        final level = Level.fromJson(jsonWithNegativeLevel);

        // Assert
        expect(level.level, equals(-1));
      });

      test('should handle very large level number', () {
        // Arrange
        final jsonWithLargeLevel = {
          'level': 999999,
          'title': 'Extreme Level',
          'sublevels': []
        };

        // Act
        final level = Level.fromJson(jsonWithLargeLevel);

        // Assert
        expect(level.level, equals(999999));
      });

      test('should handle special characters in title', () {
        // Arrange
        const specialTitle = 'བོད་སྐད་སྦྱང་བའི་རིམ་པ།';
        final jsonWithSpecialTitle = {
          'level': 1,
          'title': specialTitle,
          'sublevels': []
        };

        // Act
        final level = Level.fromJson(jsonWithSpecialTitle);

        // Assert
        expect(level.title, equals(specialTitle));
      });

      test('should handle very long title', () {
        // Arrange
        final longTitle = 'A' * 1000;
        final jsonWithLongTitle = {
          'level': 1,
          'title': longTitle,
          'sublevels': []
        };

        // Act
        final level = Level.fromJson(jsonWithLongTitle);

        // Assert
        expect(level.title.length, equals(1000));
      });
    });

    group('Sublevel Integration Tests', () {
      test('should properly parse complex sublevel structures', () {
        // Arrange
        final complexJson = {
          'level': 2,
          'title': 'Intermediate',
          'sublevels': [
            {
              'level': '2.1',
              'name': 'Grammar Basics',
              'path': 'assets/quiz_data/level-2/grammar-basics.json'
            },
            {
              'level': '2.2',
              'name': 'Sentence Structure',
              'path': 'assets/quiz_data/level-2/sentence-structure.json'
            },
            {
              'level': '2.3',
              'name': 'Complex Conversations'
              // Missing path to test default behavior
            }
          ]
        };

        // Act
        final level = Level.fromJson(complexJson);

        // Assert
        expect(level.sublevels, hasLength(3));
        expect(level.sublevels[0].name, equals('Grammar Basics'));
        expect(level.sublevels[1].path, contains('sentence-structure.json'));
        expect(level.sublevels[2].path, equals(''));
      });
    });
  });
}


