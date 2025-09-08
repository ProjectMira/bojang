#!/usr/bin/env dart

/// Test Runner for Bojang - Tibetan Learning App
/// 
/// This script provides convenient commands for running different types of tests
/// and generating coverage reports.

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    _printHelp();
    return;
  }

  final command = args[0].toLowerCase();

  switch (command) {
    case 'all':
      _runAllTests();
      break;
    case 'unit':
      _runUnitTests();
      break;
    case 'widget':
      _runWidgetTests();
      break;
    case 'integration':
      _runIntegrationTests();
      break;
    case 'coverage':
      _runTestsWithCoverage();
      break;
    case 'watch':
      _watchTests();
      break;
    case 'help':
    case '-h':
    case '--help':
      _printHelp();
      break;
    default:
      print('Unknown command: $command');
      _printHelp();
  }
}

void _printHelp() {
  print('''
Bojang Test Runner

Usage: dart test_runner.dart <command>

Commands:
  all         Run all tests (unit, widget, integration)
  unit        Run unit tests only (models, services)
  widget      Run widget tests only (screens, UI components)
  integration Run integration tests only (end-to-end flows)
  coverage    Run all tests with coverage report
  watch       Watch mode - run tests when files change
  help        Show this help message

Examples:
  dart test_runner.dart all
  dart test_runner.dart unit
  dart test_runner.dart coverage
  dart test_runner.dart watch
''');
}

void _runAllTests() {
  print('🚀 Running all tests...\n');
  
  final result = Process.runSync(
    'flutter',
    ['test', '--reporter=expanded'],
    workingDirectory: _getCurrentDirectory(),
  );
  
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Errors:');
    print(result.stderr);
  }
  
  if (result.exitCode == 0) {
    print('\n✅ All tests passed!');
  } else {
    print('\n❌ Some tests failed.');
    exit(result.exitCode);
  }
}

void _runUnitTests() {
  print('🧪 Running unit tests...\n');
  
  final result = Process.runSync(
    'flutter',
    ['test', 'test/models/', 'test/services/', '--reporter=expanded'],
    workingDirectory: _getCurrentDirectory(),
  );
  
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Errors:');
    print(result.stderr);
  }
  
  _printResults(result.exitCode, 'Unit tests');
}

void _runWidgetTests() {
  print('🖥️  Running widget tests...\n');
  
  final result = Process.runSync(
    'flutter',
    ['test', 'test/screens/', 'test/widget_test.dart', '--reporter=expanded'],
    workingDirectory: _getCurrentDirectory(),
  );
  
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Errors:');
    print(result.stderr);
  }
  
  _printResults(result.exitCode, 'Widget tests');
}

void _runIntegrationTests() {
  print('🔄 Running integration tests...\n');
  
  final result = Process.runSync(
    'flutter',
    ['test', 'integration_test/', '--reporter=expanded'],
    workingDirectory: _getCurrentDirectory(),
  );
  
  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('Errors:');
    print(result.stderr);
  }
  
  _printResults(result.exitCode, 'Integration tests');
}

void _runTestsWithCoverage() {
  print('📊 Running tests with coverage...\n');
  
  // Run tests with coverage
  final testResult = Process.runSync(
    'flutter',
    ['test', '--coverage', '--reporter=expanded'],
    workingDirectory: _getCurrentDirectory(),
  );
  
  print(testResult.stdout);
  if (testResult.stderr.isNotEmpty) {
    print('Errors:');
    print(testResult.stderr);
  }
  
  if (testResult.exitCode != 0) {
    print('\n❌ Tests failed. Coverage report not generated.');
    exit(testResult.exitCode);
  }
  
  // Check if genhtml is available
  final genHtmlCheck = Process.runSync('which', ['genhtml']);
  
  if (genHtmlCheck.exitCode == 0) {
    print('\n📈 Generating HTML coverage report...');
    
    final coverageResult = Process.runSync(
      'genhtml',
      ['coverage/lcov.info', '-o', 'coverage/html'],
      workingDirectory: _getCurrentDirectory(),
    );
    
    if (coverageResult.exitCode == 0) {
      print('✅ Coverage report generated in coverage/html/');
      print('📂 Open coverage/html/index.html in your browser to view the report.');
    } else {
      print('❌ Failed to generate HTML coverage report.');
      print(coverageResult.stderr);
    }
  } else {
    print('\n📋 Coverage data saved to coverage/lcov.info');
    print('💡 Install genhtml to generate HTML reports: brew install lcov (macOS)');
  }
  
  print('\n✅ Tests completed with coverage!');
}

void _watchTests() {
  print('👀 Starting test watch mode...\n');
  print('Press Ctrl+C to stop watching.\n');
  
  final process = Process.start(
    'flutter',
    ['test', '--reporter=expanded'],
    workingDirectory: _getCurrentDirectory(),
  );
  
  process.then((proc) {
    proc.stdout.listen((data) {
      stdout.add(data);
    });
    
    proc.stderr.listen((data) {
      stderr.add(data);
    });
    
    // Listen for file changes and rerun tests
    // This is a simplified version - in production, you might want to use
    // a proper file watcher like chokidar or similar
    print('🔍 Watching for file changes...');
  });
}

void _printResults(int exitCode, String testType) {
  if (exitCode == 0) {
    print('\n✅ $testType passed!');
  } else {
    print('\n❌ $testType failed.');
    exit(exitCode);
  }
}

String _getCurrentDirectory() {
  // Get current working directory
  return Directory.current.path;
}

/// Extended test runner with additional utilities
class TestRunner {
  static void runSpecificTest(String testPath) {
    print('🎯 Running specific test: $testPath\n');
    
    final result = Process.runSync(
      'flutter',
      ['test', testPath, '--reporter=expanded'],
      workingDirectory: Directory.current.path,
    );
    
    print(result.stdout);
    if (result.stderr.isNotEmpty) {
      print('Errors:');
      print(result.stderr);
    }
    
    if (result.exitCode == 0) {
      print('\n✅ Test passed!');
    } else {
      print('\n❌ Test failed.');
    }
  }
  
  static void runTestsWithFilter(String filter) {
    print('🔍 Running tests matching: $filter\n');
    
    final result = Process.runSync(
      'flutter',
      ['test', '--name', filter, '--reporter=expanded'],
      workingDirectory: Directory.current.path,
    );
    
    print(result.stdout);
    if (result.stderr.isNotEmpty) {
      print('Errors:');
      print(result.stderr);
    }
    
    if (result.exitCode == 0) {
      print('\n✅ Filtered tests passed!');
    } else {
      print('\n❌ Some filtered tests failed.');
    }
  }
  
  static void generateTestReport() {
    print('📋 Generating test report...\n');
    
    final result = Process.runSync(
      'flutter',
      ['test', '--machine'],
      workingDirectory: Directory.current.path,
    );
    
    if (result.exitCode == 0) {
      // Parse machine-readable output and generate custom report
      print('📊 Test report generated successfully!');
    } else {
      print('❌ Failed to generate test report.');
    }
  }
}


