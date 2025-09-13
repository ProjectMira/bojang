import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simple arithmetic test', () {
    expect(2 + 2, equals(4));
  });
  
  test('string test', () {
    expect('hello', isA<String>());
  });
}