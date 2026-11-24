/// The landscapes the learning path walks through, one per unit.
///
/// The journey climbs: it starts in a river valley with barley fields and
/// whitewashed houses, crosses the nomads' pastures, passes a turquoise lake,
/// a Kham forest, a monastery on its ridge and the Changtang plateau, and
/// tops out at a snow pass. Past the seventh unit it starts again in a new
/// valley.
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

enum Biome {
  /// River valley: barley fields, whitewashed houses, a chorten, poplars.
  valley,

  /// Drokpa pastures: rolling grass, black yak-hair tents, grazing yaks.
  pasture,

  /// A turquoise lake under snow peaks, mani stones and prayer flags.
  lake,

  /// Kham forest valley: conifers, timber houses, rhododendrons.
  forest,

  /// A monastery on its ridge, chortens and a smoking sang offering.
  monastery,

  /// The Changtang high plateau: wide ochre flats, a salt lake, kiang.
  plateau,

  /// A high pass (la): snow ranges, a glacier, a lhatse cairn with flags.
  pass,
}

extension BiomeX on Biome {
  /// How the biome is named to the learner (semantics only).
  String get label => switch (this) {
    Biome.valley => 'river valley',
    Biome.pasture => 'nomad pastures',
    Biome.lake => 'turquoise lake',
    Biome.forest => 'forest valley',
    Biome.monastery => 'monastery ridge',
    Biome.plateau => 'high plateau',
    Biome.pass => 'snow pass',
  };

  /// The prayer-flag hue its open steps wear. Neighbouring biomes never
  /// share one.
  AppHue get hue => switch (this) {
    Biome.valley => AppPalette.red,
    Biome.pasture => AppPalette.green,
    Biome.lake => AppPalette.blue,
    Biome.forest => AppPalette.green,
    Biome.monastery => AppPalette.saffron,
    Biome.plateau => AppPalette.lapis,
    Biome.pass => AppPalette.blue,
  };
}

/// The biome of the unit with 1-based [unitIndex], cycling after seven.
Biome biomeForUnit(int unitIndex) {
  final n = Biome.values.length;
  final i = ((unitIndex - 1) % n + n) % n;
  return Biome.values[i];
}

/// Colours of one biome, already resolved for day or night.
@immutable
class BiomePalette {
  const BiomePalette({
    required this.mist,
    required this.skyHigh,
    required this.horizon,
    required this.far,
    required this.snow,
    required this.snowShade,
    required this.mid,
    required this.near,
    required this.ground,
    required this.groundShade,
    required this.trail,
    required this.trailEdge,
    required this.water,
    required this.waterDeep,
    required this.wall,
    required this.frame,
    required this.window,
    required this.dark,
  });

  /// The cloud band between two biomes; also the page colour around them.
  final Color mist;
  final Color skyHigh;
  final Color horizon;

  /// The farthest range.
  final Color far;
  final Color snow;
  final Color snowShade;
  final Color mid;
  final Color near;
  final Color ground;
  final Color groundShade;
  final Color trail;
  final Color trailEdge;
  final Color water;
  final Color waterDeep;

  /// Whitewashed walls, black window frames, window glass (lamp-lit at
  /// night).
  final Color wall;
  final Color frame;
  final Color window;
  final bool dark;

  static const Color mistDay = Color(0xFFEEF3F8);
  static const Color mistNight = Color(0xFF0F1626);

  /// The page colour the scenery fades into, for [dark] or day.
  static Color mistFor(bool dark) => dark ? mistNight : mistDay;

  static BiomePalette of(Biome biome, {required bool dark}) {
    final day = _day(biome);
    return dark ? _night(day) : day;
  }

  static BiomePalette _day(Biome biome) {
    const mist = mistDay;
    const wall = Color(0xFFF7F5F0);
    const frame = Color(0xFF26231F);
    const window = Color(0xFF3B3A3A);
    const snow = Color(0xFFFFFFFF);
    const snowShade = Color(0xFFC9D6E6);
    const water = Color(0xFF2FA7A0);
    const waterDeep = Color(0xFF1F7E8A);
    BiomePalette p({
      Color skyHigh = const Color(0xFF9CC8EA),
      Color horizon = const Color(0xFFDDEBF4),
      required Color far,
      required Color mid,
      required Color near,
      required Color ground,
      required Color groundShade,
      required Color trail,
      required Color trailEdge,
      Color w = water,
      Color wd = waterDeep,
    }) => BiomePalette(
      mist: mist,
      skyHigh: skyHigh,
      horizon: horizon,
      far: far,
      snow: snow,
      snowShade: snowShade,
      mid: mid,
      near: near,
      ground: ground,
      groundShade: groundShade,
      trail: trail,
      trailEdge: trailEdge,
      water: w,
      waterDeep: wd,
      wall: wall,
      frame: frame,
      window: window,
      dark: false,
    );
    return switch (biome) {
      Biome.valley => p(
        far: const Color(0xFFA8B7CB),
        mid: const Color(0xFFB59B79),
        near: const Color(0xFF93A65E),
        ground: const Color(0xFFA7B862),
        groundShade: const Color(0xFF8C9D4C),
        trail: const Color(0xFFEADFC2),
        trailEdge: const Color(0xFFC5B086),
        w: const Color(0xFF5AA7C9),
        wd: const Color(0xFF3A86AA),
      ),
      Biome.pasture => p(
        far: const Color(0xFF9DB2C8),
        mid: const Color(0xFF739F6B),
        near: const Color(0xFF5E9150),
        ground: const Color(0xFF7BAA58),
        groundShade: const Color(0xFF608E45),
        trail: const Color(0xFFE4D9B4),
        trailEdge: const Color(0xFFB9A77B),
      ),
      Biome.lake => p(
        far: const Color(0xFFA6B5CA),
        mid: const Color(0xFFB59C80),
        near: const Color(0xFF9F8E6C),
        ground: const Color(0xFFBAB487),
        groundShade: const Color(0xFF9E996D),
        trail: const Color(0xFFEFE6CB),
        trailEdge: const Color(0xFFC7B78F),
      ),
      Biome.forest => p(
        far: const Color(0xFF8FA6B6),
        mid: const Color(0xFF477361),
        near: const Color(0xFF365F49),
        ground: const Color(0xFF527F50),
        groundShade: const Color(0xFF3F6B41),
        trail: const Color(0xFFDCCCA3),
        trailEdge: const Color(0xFFA9976C),
        w: const Color(0xFF4C9DB5),
        wd: const Color(0xFF2F7C96),
      ),
      Biome.monastery => p(
        far: const Color(0xFFADBACD),
        mid: const Color(0xFFB38E60),
        near: const Color(0xFF9D7B4F),
        ground: const Color(0xFFC4A66E),
        groundShade: const Color(0xFFA98C58),
        trail: const Color(0xFFF0E3C3),
        trailEdge: const Color(0xFFC8AE7C),
      ),
      Biome.plateau => p(
        skyHigh: const Color(0xFF8DBFE8),
        far: const Color(0xFFB8C3D1),
        mid: const Color(0xFFC3A885),
        near: const Color(0xFFB4906B),
        ground: const Color(0xFFCFB98B),
        groundShade: const Color(0xFFB79F71),
        trail: const Color(0xFFF1E7CD),
        trailEdge: const Color(0xFFC9B184),
        w: const Color(0xFFF3F5F2),
        wd: const Color(0xFFD9E2E0),
      ),
      Biome.pass => p(
        skyHigh: const Color(0xFF79ACDE),
        horizon: const Color(0xFFD4E5F3),
        far: const Color(0xFFC9D5E4),
        mid: const Color(0xFF8E9AAA),
        near: const Color(0xFFE6ECF3),
        ground: const Color(0xFFDDE5EE),
        groundShade: const Color(0xFFB9C6D5),
        trail: const Color(0xFFBDB29B),
        trailEdge: const Color(0xFF9C8F75),
      ),
    };
  }

  /// Moonlight: everything sinks toward the night blue, snow and walls keep
  /// a pale glow and the windows hold butter-lamp light.
  static BiomePalette _night(BiomePalette d) {
    const nightBlue = Color(0xFF0E1C3A);
    Color sink(Color c, double t) => Color.lerp(_grey(c, 0.15), nightBlue, t)!;
    return BiomePalette(
      mist: mistNight,
      skyHigh: const Color(0xFF15254A),
      horizon: const Color(0xFF2A3F66),
      far: sink(d.far, 0.45),
      snow: const Color(0xFFB4C4DB),
      snowShade: const Color(0xFF7C8FAD),
      mid: sink(d.mid, 0.62),
      near: sink(d.near, 0.68),
      ground: sink(d.ground, 0.62),
      groundShade: sink(d.groundShade, 0.72),
      trail: sink(d.trail, 0.55),
      trailEdge: sink(d.trailEdge, 0.68),
      water: sink(d.water, 0.5),
      waterDeep: sink(d.waterDeep, 0.6),
      wall: const Color(0xFF9DABC2),
      frame: const Color(0xFF151820),
      window: const Color(0xFFF3C25A),
      dark: true,
    );
  }

  /// A prop colour for this palette: [day] as is, or sunk into the night.
  Color tone(Color day, [double depth = 0.6]) =>
      dark
          ? Color.lerp(_grey(day, 0.45), const Color(0xFF111B30), depth)!
          : day;

  static Color _grey(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withSaturation(hsl.saturation * (1 - amount)).toColor();
  }

  @override
  bool operator ==(Object other) =>
      other is BiomePalette &&
      other.dark == dark &&
      other.far == far &&
      other.mid == mid &&
      other.ground == ground &&
      other.skyHigh == skyHigh &&
      other.trail == trail &&
      other.water == water;

  @override
  int get hashCode =>
      Object.hash(dark, far, mid, ground, skyHigh, trail, water);
}
