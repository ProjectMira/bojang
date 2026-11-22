import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How many Memory Match pairs fit on one board, and how to lay them out.
///
/// Phones keep the familiar board of 2 pairs (4 cards). Tablets fit as many
/// pairs as the screen holds while every card stays at least [minCardSide]
/// on its short side and not too stretched, up to [maxPairs].
class MemoryBoardLayout {
  MemoryBoardLayout._();

  static const int phonePairs = 2;
  static const int maxPairs = 8;
  static const double minCardSide = 150;
  static const double spacing = 16;

  /// Pairs per board for a grid area of [area] (the space the cards get).
  static int pairsFor(Size area, {required bool isTablet}) {
    if (!isTablet) return phonePairs;
    for (var pairs = maxPairs; pairs > phonePairs; pairs--) {
      final grid = gridFor(pairs * 2, area);
      if (grid != null && grid.cardSize.shortestSide >= minCardSide) {
        return pairs;
      }
    }
    return phonePairs;
  }

  /// The best grid for [cards] cards in [area]: the column count giving the
  /// largest cards whose shape stays between 0.6 and 1.4 (width / height).
  /// Null when no column count gives a usable shape.
  static MemoryGrid? gridFor(int cards, Size area) {
    MemoryGrid? best;
    for (var columns = 2; columns <= math.min(cards, 6); columns++) {
      final rows = (cards / columns).ceil();
      final width = (area.width - spacing * (columns - 1)) / columns;
      final height = (area.height - spacing * (rows - 1)) / rows;
      if (width <= 0 || height <= 0) continue;
      final aspect = width / height;
      if (aspect < 0.6 || aspect > 1.4) continue;
      final grid = MemoryGrid(columns, Size(width, height));
      if (best == null || grid.cardSize.shortestSide > best.cardSize.shortestSide) {
        best = grid;
      }
    }
    return best;
  }
}

class MemoryGrid {
  final int columns;
  final Size cardSize;

  const MemoryGrid(this.columns, this.cardSize);

  double get aspectRatio => cardSize.width / cardSize.height;
}
