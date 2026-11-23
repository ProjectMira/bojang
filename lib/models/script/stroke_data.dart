/// Stroke paths for the 30 Tibetan consonants, for tracing and the
/// stroke animation on the character sheet.
///
/// Original vector data drawn for Bojang (not traced from a font): each
/// letter is an ordered list of strokes, each stroke an ordered list of
/// points in a 100 x 100 box. The headline sits at y = 20 and the letter
/// body between y = 20 and y = 60; long tails reach y = 90. Order is
/// headline first, then left to right and top to bottom, the usual
/// teaching order for uchen; a calligrapher should review it.
library;

import 'dart:ui';

class StrokeData {
  StrokeData._();

  /// Size of the box the points are in.
  static const double box = 100;

  /// Letters that have stroke data (all 30 consonants).
  static Iterable<String> get letters => _strokes.keys;

  /// The strokes of [char], or null when there are none.
  static List<List<Offset>>? of(String char) => _strokes[char];

  static bool has(String char) => _strokes.containsKey(char);

  static const Map<String, List<List<Offset>>> _strokes = {
    'ཀ': [[Offset(36, 21), Offset(71, 21)], [Offset(40, 23), Offset(37, 33), Offset(28, 41)], [Offset(49, 23), Offset(50, 52)], [Offset(66, 22), Offset(66, 88)]],
    'ཁ': [[Offset(36, 21), Offset(70, 21)], [Offset(37, 22), Offset(37, 55)], [Offset(40, 42), Offset(52, 32), Offset(66, 46)], [Offset(66, 22), Offset(66, 48)]],
    'ག': [[Offset(36, 21), Offset(71, 21)], [Offset(38, 22), Offset(38, 38), Offset(28, 42)], [Offset(50, 22), Offset(51, 52)], [Offset(66, 22), Offset(66, 88)]],
    'ང': [[Offset(38, 22), Offset(60, 20)], [Offset(45, 22), Offset(45, 37)], [Offset(34, 42), Offset(48, 40), Offset(68, 58)]],
    'ཅ': [[Offset(34, 20), Offset(66, 20)], [Offset(50, 21), Offset(48, 30), Offset(34, 36)], [Offset(40, 38), Offset(38, 50), Offset(50, 58), Offset(64, 52), Offset(64, 42), Offset(52, 38)]],
    'ཆ': [[Offset(32, 20), Offset(72, 20)], [Offset(50, 21), Offset(50, 28)], [Offset(48, 30), Offset(36, 36), Offset(36, 52), Offset(48, 54), Offset(50, 40)], [Offset(50, 40), Offset(52, 54), Offset(66, 52), Offset(68, 38), Offset(56, 32)]],
    'ཇ': [[Offset(36, 20), Offset(62, 20)], [Offset(38, 21), Offset(38, 50)], [Offset(38, 33), Offset(54, 32), Offset(62, 30)], [Offset(34, 52), Offset(50, 50), Offset(68, 58)]],
    'ཉ': [[Offset(34, 21), Offset(62, 20)], [Offset(46, 21), Offset(36, 27), Offset(37, 37), Offset(46, 40)], [Offset(46, 40), Offset(40, 46), Offset(44, 54), Offset(52, 50)], [Offset(58, 24), Offset(64, 40), Offset(60, 60), Offset(40, 90)]],
    'ཏ': [[Offset(36, 21), Offset(66, 20)], [Offset(37, 22), Offset(36, 34)], [Offset(56, 21), Offset(66, 32), Offset(62, 44), Offset(46, 44)], [Offset(62, 44), Offset(56, 64), Offset(40, 90)]],
    'ཐ': [[Offset(36, 21), Offset(66, 21)], [Offset(38, 22), Offset(38, 46), Offset(32, 52)], [Offset(39, 34), Offset(64, 34)], [Offset(65, 22), Offset(64, 58)], [Offset(38, 44), Offset(64, 58)]],
    'ད': [[Offset(34, 21), Offset(64, 20)], [Offset(42, 22), Offset(34, 38), Offset(48, 40)], [Offset(50, 22), Offset(62, 30), Offset(66, 60), Offset(67, 88)]],
    'ན': [[Offset(36, 21), Offset(66, 20)], [Offset(48, 22), Offset(44, 32), Offset(36, 42), Offset(40, 52), Offset(48, 50), Offset(46, 42), Offset(38, 42)], [Offset(60, 30), Offset(62, 60), Offset(63, 88)]],
    'པ': [[Offset(32, 22), Offset(40, 22)], [Offset(36, 22), Offset(36, 40), Offset(48, 46), Offset(64, 54)], [Offset(60, 22), Offset(64, 21), Offset(64, 54)]],
    'ཕ': [[Offset(32, 22), Offset(40, 22)], [Offset(36, 22), Offset(36, 40), Offset(48, 46), Offset(64, 54)], [Offset(60, 22), Offset(64, 21), Offset(64, 54)], [Offset(60, 24), Offset(52, 30), Offset(46, 38)]],
    'བ': [[Offset(34, 21), Offset(70, 20)], [Offset(36, 22), Offset(36, 40), Offset(48, 46), Offset(64, 54)], [Offset(66, 21), Offset(64, 54)]],
    'མ': [[Offset(30, 28), Offset(40, 24), Offset(46, 30), Offset(42, 44), Offset(34, 46), Offset(30, 40), Offset(36, 36), Offset(44, 40)], [Offset(52, 24), Offset(58, 42), Offset(68, 58)], [Offset(66, 22), Offset(68, 58)]],
    'ཙ': [[Offset(34, 20), Offset(66, 20)], [Offset(54, 20), Offset(62, 14), Offset(70, 8)], [Offset(50, 21), Offset(48, 30), Offset(34, 36)], [Offset(40, 38), Offset(38, 50), Offset(50, 58), Offset(64, 52), Offset(64, 42), Offset(52, 38)]],
    'ཚ': [[Offset(32, 20), Offset(72, 20)], [Offset(56, 20), Offset(64, 14), Offset(72, 8)], [Offset(50, 21), Offset(50, 28)], [Offset(48, 30), Offset(36, 36), Offset(36, 52), Offset(48, 54), Offset(50, 40)], [Offset(50, 40), Offset(52, 54), Offset(66, 52), Offset(68, 38), Offset(56, 32)]],
    'ཛ': [[Offset(36, 20), Offset(62, 20)], [Offset(54, 20), Offset(62, 14), Offset(70, 8)], [Offset(38, 21), Offset(38, 50)], [Offset(38, 33), Offset(54, 32), Offset(62, 30)], [Offset(34, 52), Offset(50, 50), Offset(68, 58)]],
    'ཝ': [[Offset(32, 22), Offset(40, 22)], [Offset(36, 22), Offset(36, 40), Offset(48, 46), Offset(64, 54)], [Offset(60, 22), Offset(64, 21), Offset(64, 54)], [Offset(46, 22), Offset(50, 34), Offset(62, 40)]],
    'ཞ': [[Offset(42, 21), Offset(66, 20)], [Offset(52, 22), Offset(36, 30), Offset(34, 48), Offset(44, 52), Offset(56, 46), Offset(54, 36), Offset(46, 38)], [Offset(66, 22), Offset(66, 60), Offset(66, 88)]],
    'ཟ': [[Offset(36, 21), Offset(66, 20)], [Offset(62, 21), Offset(62, 58)], [Offset(38, 35), Offset(62, 35)], [Offset(34, 52), Offset(62, 52)]],
    'འ': [[Offset(36, 32), Offset(38, 24), Offset(50, 20), Offset(62, 24), Offset(66, 34), Offset(68, 58)], [Offset(40, 30), Offset(40, 40), Offset(50, 42)]],
    'ཡ': [[Offset(28, 28), Offset(36, 24), Offset(38, 40), Offset(48, 48), Offset(64, 52)], [Offset(50, 22), Offset(50, 38)], [Offset(66, 22), Offset(68, 54)]],
    'ར': [[Offset(34, 22), Offset(62, 20)], [Offset(44, 22), Offset(42, 34)], [Offset(34, 40), Offset(48, 38), Offset(70, 58)]],
    'ལ': [[Offset(30, 26), Offset(38, 22), Offset(38, 38), Offset(32, 42)], [Offset(34, 34), Offset(46, 48), Offset(66, 54)], [Offset(48, 22), Offset(52, 36)], [Offset(64, 22), Offset(66, 54)]],
    'ཤ': [[Offset(66, 22), Offset(56, 22), Offset(50, 30), Offset(56, 38), Offset(64, 34), Offset(62, 26)], [Offset(68, 20), Offset(66, 60), Offset(65, 88)], [Offset(30, 48), Offset(38, 40), Offset(44, 48), Offset(42, 54)]],
    'ས': [[Offset(30, 26), Offset(40, 24), Offset(46, 34), Offset(56, 48), Offset(66, 56)], [Offset(30, 42), Offset(40, 44)], [Offset(46, 22), Offset(52, 30), Offset(64, 26)], [Offset(66, 22), Offset(66, 56)]],
    'ཧ': [[Offset(36, 21), Offset(66, 20)], [Offset(52, 22), Offset(64, 30), Offset(60, 42)], [Offset(36, 40), Offset(42, 44), Offset(58, 44)], [Offset(60, 44), Offset(54, 66), Offset(42, 90)]],
    'ཨ': [[Offset(46, 21), Offset(70, 21)], [Offset(40, 22), Offset(30, 30), Offset(28, 44), Offset(36, 54), Offset(46, 52)], [Offset(40, 24), Offset(50, 40), Offset(62, 50)], [Offset(66, 22), Offset(68, 58)]],
  };
}
