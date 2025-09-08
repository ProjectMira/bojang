// Simple test runner to identify issues
import 'package:flutter_test/flutter_test.dart';
import 'test/test_helpers.dart';

void main() {
  group('Simple Test Runner', () {
    test('test helpers initialization', () {
      expect(TestHelpers.mockLevelsData, isNotEmpty);
      expect(TestHelpers.mockQuizData, isNotEmpty);
    });

    test('mock setup and cleanup', () {
      TestHelpers.setupAllMocks();
      TestHelpers.cleanupAllMocks();
      // Should not throw any errors
      expect(true, isTrue);
    });
  });
}

