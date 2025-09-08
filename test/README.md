# Test Suite for Bojang - Tibetan Learning App

This directory contains comprehensive tests for the Bojang Tibetan Learning app, covering all aspects of the application including models, services, screens, and user flows.

## Test Structure

```
test/
├── README.md                              # This file
├── widget_test.dart                       # Main app widget tests
├── models/                               # Model unit tests
│   ├── quiz_question_test.dart
│   └── level_models_test.dart
├── services/                             # Service unit tests
│   └── notification_service_test.dart
├── screens/                              # Screen widget tests
│   ├── splash_screen_test.dart
│   ├── home_page_test.dart
│   ├── level_selection_screen_test.dart
│   ├── quiz_screen_test.dart
│   └── notification_settings_screen_test.dart
└── mocks/                                # Mock classes and test utilities
    └── mock_notifications.dart

integration_test/
└── app_integration_test.dart             # End-to-end integration tests
```

## Test Categories

### 1. Unit Tests
Tests individual components in isolation:
- **Models**: Test data parsing, validation, and edge cases
- **Services**: Test business logic and external service integration

### 2. Widget Tests
Test individual screens and UI components:
- **Screen Widgets**: Test UI rendering, user interactions, and state management
- **Navigation**: Test screen transitions and routing
- **Animations**: Test animation behavior and timing

### 3. Integration Tests
Test complete user flows and app behavior:
- **End-to-End Flows**: Complete user journeys from splash to quiz completion
- **Cross-Screen Navigation**: Multi-screen workflows
- **Error Scenarios**: Error handling and recovery flows

## Test Coverage

### Models (`test/models/`)
- **QuizQuestion**: JSON parsing, validation, edge cases, error handling
- **Level & Sublevel**: Data structure parsing, nested object handling

### Services (`test/services/`)
- **NotificationService**: Singleton pattern, scheduling, cancellation, error handling

### Screens (`test/screens/`)
- **SplashScreen**: Animation, navigation timing, resource disposal
- **HomePage**: Simple wrapper functionality, integration with LevelSelectionScreen  
- **LevelSelectionScreen**: Data loading, level rendering, sublevel interactions, navigation
- **QuizScreen**: Question display, answer handling, score tracking, completion flow
- **NotificationSettingsScreen**: Settings toggle, test notifications, state persistence

### Integration (`integration_test/`)
- Complete app flows from launch to quiz completion
- Settings management and persistence
- Error handling and recovery
- Performance and memory management
- Accessibility and responsive design

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test Categories
```bash
# Unit tests only
flutter test test/models/ test/services/

# Widget tests only  
flutter test test/screens/ test/widget_test.dart

# Integration tests
flutter test integration_test/
```

### Run Tests with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Run Individual Test Files
```bash
# Run specific test file
flutter test test/models/quiz_question_test.dart

# Run with verbose output
flutter test test/screens/quiz_screen_test.dart --reporter=expanded
```

## Test Features

### Comprehensive Coverage
- **Business Logic**: All core app functionality
- **UI Components**: Every screen, button, and interaction
- **Edge Cases**: Error conditions, empty states, invalid data
- **Performance**: Loading times, memory management, resource disposal
- **Accessibility**: Screen reader support, large text handling

### Realistic Testing
- **Mock Data**: Simulates actual quiz data and API responses
- **Asset Loading**: Tests real asset loading scenarios
- **Animation Testing**: Verifies timing and smooth transitions
- **State Management**: Tests data persistence and state updates

### Error Scenarios
- **Network Failures**: Simulates connection issues
- **Invalid Data**: Tests handling of malformed JSON and missing files
- **Resource Constraints**: Tests behavior under memory pressure
- **User Errors**: Tests invalid user inputs and edge cases

## Mock Strategy

### Asset Loading
Tests use `TestDefaultBinaryMessengerBinding` to mock asset loading:
- Valid quiz data for happy path testing
- Invalid JSON for error handling testing
- Missing assets for failure scenario testing

### External Services
- **Notification Service**: Mocked to test scheduling and cancellation
- **Audio Player**: Graceful handling when audio fails to load
- **File System**: Mocked asset bundle for consistent test data

## Test Data

### Sample Quiz Data
```json
{
  "exercises": [
    {
      "type": "character_recognition",
      "tibetanText": "ཀ",
      "options": ["ka", "ga", "kha"],
      "correctAnswerIndex": 0
    }
  ]
}
```

### Sample Level Data
```json
{
  "levels": [
    {
      "level": 1,
      "title": "Beginner",
      "sublevels": [
        {
          "level": "1.1", 
          "name": "Alphabet",
          "path": "assets/quiz_data/level-1/alphabet.json"
        }
      ]
    }
  ]
}
```

## CI/CD Integration

These tests are designed to run in continuous integration environments:
- **Headless Testing**: All tests run without requiring display
- **Deterministic**: Tests produce consistent results across runs
- **Fast Execution**: Optimized for quick feedback cycles
- **Comprehensive Reports**: Detailed output for debugging failures

## Contributing to Tests

When adding new features, ensure you:
1. Add unit tests for new models and services
2. Add widget tests for new screens and components  
3. Update integration tests for new user flows
4. Test both happy path and error scenarios
5. Verify tests pass in CI environment

## Debugging Tests

### Common Issues
1. **Asset Loading Failures**: Ensure mock data is properly formatted JSON
2. **Timing Issues**: Use `pumpAndSettle()` for animations and async operations
3. **State Management**: Reset state between tests using `setUp()` and `tearDown()`
4. **Platform Differences**: Test on multiple platforms if target platforms differ

### Debug Tips
```dart
// Add debug output in tests
print('Current widget tree: ${tester.allWidgets}');

// Pause test execution for debugging
await tester.pump(Duration.zero);
debugger();

// Check for exceptions
expect(tester.takeException(), isNull);
```

This test suite ensures the Bojang app is reliable, user-friendly, and performs well across all supported platforms and scenarios.


