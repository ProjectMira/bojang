// Minimal test to validate test infrastructure
import 'package:flutter_test/flutter_test.dart';
import 'package:bojang/models/level_models.dart';

void main() {
  group('Minimal Test Suite', () {
    test('basic test should pass', () {
      expect(1 + 1, equals(2));
    });

    test('Level model should create instance', () {
      final level = Level(
        level: 1,
        title: 'Test',
        sublevels: [],
      );
      expect(level.level, equals(1));
      expect(level.title, equals('Test'));
    });

    test('Sublevel model should create instance', () {
      final sublevel = Sublevel(
        level: '1.1',
        name: 'Test',
        path: 'test/path.json',
      );
      expect(sublevel.level, equals('1.1'));
      expect(sublevel.name, equals('Test'));
    });
  });
}

