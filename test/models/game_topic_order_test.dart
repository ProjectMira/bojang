import 'package:bojang/services/game_topic_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ids = ['basics-letters-1', 'basics-letters-2', 'vocab-fruits', 'vocab-animals', 'vocab-body'];
  String id(String s) => s;

  test('after the beginner stage the alphabet goes last, course order kept', () {
    expect(GameTopicOrder.sort(ids, id, recentIds: const [], beginner: false),
        ['vocab-fruits', 'vocab-animals', 'vocab-body', 'basics-letters-1', 'basics-letters-2']);
  });

  test('recently played come first, most recent first', () {
    expect(GameTopicOrder.sort(ids, id, recentIds: const ['vocab-body', 'basics-letters-2'], beginner: false),
        ['vocab-body', 'basics-letters-2', 'vocab-fruits', 'vocab-animals', 'basics-letters-1']);
  });

  test('beginners keep course order (alphabet first)', () {
    expect(GameTopicOrder.sort(ids, id, recentIds: const [], beginner: true), ids);
  });
}
