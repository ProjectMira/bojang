import 'package:bojang/utils/memory_board_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phones keep the board of 4 cards', () {
    expect(MemoryBoardLayout.pairsFor(const Size(354, 560), isTablet: false), 2);
    expect(MemoryBoardLayout.pairsFor(const Size(1000, 1000), isTablet: false), 2);
  });

  test('an iPad in portrait fits 16 cards', () {
    // iPad Pro 11": 834 wide, grid area after stats and padding.
    final pairs = MemoryBoardLayout.pairsFor(const Size(786, 820), isTablet: true);
    expect(pairs, 8);
    final grid = MemoryBoardLayout.gridFor(pairs * 2, const Size(786, 820))!;
    expect(grid.columns, 4);
    expect(grid.cardSize.shortestSide, greaterThanOrEqualTo(MemoryBoardLayout.minCardSide));
  });

  test('a small or short tablet area gets more than 4 cards when they fit', () {
    final pairs = MemoryBoardLayout.pairsFor(const Size(700, 420), isTablet: true);
    expect(pairs, greaterThan(2));
    expect(pairs, lessThan(8));
  });

  test('cards never get too small or stretched', () {
    for (final area in const [Size(600, 300), Size(1300, 600), Size(760, 900)]) {
      final pairs = MemoryBoardLayout.pairsFor(area, isTablet: true);
      final grid = MemoryBoardLayout.gridFor(pairs * 2, area);
      if (pairs > 2) {
        expect(grid, isNotNull);
        expect(grid!.aspectRatio, inInclusiveRange(0.6, 1.4));
      }
    }
  });
}
