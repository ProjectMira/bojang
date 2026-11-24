/// The landscapes the learning path walks through, one per unit.
///
/// The journey climbs: it starts in a river valley at morning, crosses the
/// nomads' pastures at noon, reaches a turquoise lake in the late
/// afternoon, walks a misty Kham forest, sees a monastery at golden hour,
/// crosses the pale Changtang and tops out at a snow pass. Past the seventh
/// unit it starts again in a new valley.
library;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

enum Biome {
  /// River valley at morning: a chorten on its knoll above the river.
  valley,

  /// Drokpa pastures at noon: black yak-hair tents and a few yaks.
  pasture,

  /// A turquoise lake in the late afternoon, one line of prayer flags.
  lake,

  /// Kham forest on a misty morning: conifers in layers of mist.
  forest,

  /// A monastery on its ridge at golden hour.
  monastery,

  /// The Changtang: a pale, vast plain with kiang.
  plateau,

  /// A high pass (la) with its lhatse cairn, crisp blue and white.
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

/// The light and colours of one biome, already resolved for day or night.
///
/// Ranges are listed far to near: each farther one is lighter, greyer and
/// bluer (aerial perspective), and [haze] is the air between them.
@immutable
class BiomePalette {
  const BiomePalette._({
    required this.biome,
    required this.dark,
    required this.mist,
    required this.sky,
    required this.sun,
    required this.glow,
    required this.sunAt,
    required this.light,
    required this.snowShade,
    required this.rockShade,
    required this.haze,
    required this.ridges,
    required this.ground,
    required this.groundShade,
    required this.groundLight,
    required this.trail,
    required this.trailEdge,
    required this.water,
    required this.waterDeep,
    required this.cloudLit,
    required this.cloudShade,
    required this.wall,
    required this.frame,
    required this.window,
    this.rays = false,
  });

  final Biome biome;
  final bool dark;

  /// The cloud between two units; also the page colour around them.
  final Color mist;

  /// Sky stops, zenith to horizon.
  final List<Color> sky;

  /// The sun (moon at night) and its glow; [sunAt] is its position as
  /// fractions of the width and of the height down to the horizon.
  final Color sun;
  final Color glow;
  final Offset sunAt;

  /// Snow in the light, snow in shadow, rock in shadow.
  final Color light;
  final Color snowShade;
  final Color rockShade;

  /// The air between ranges.
  final Color haze;

  /// Five ranges, farthest first.
  final List<Color> ridges;

  final Color ground;
  final Color groundShade;
  final Color groundLight;
  final Color trail;
  final Color trailEdge;
  final Color water;
  final Color waterDeep;
  final Color cloudLit;
  final Color cloudShade;

  /// Whitewashed walls, black window frames, window glass (lamp-lit at
  /// night).
  final Color wall;
  final Color frame;
  final Color window;

  /// Faint shafts of light from the sun.
  final bool rays;

  Color get skyHigh => sky.first;
  Color get horizon => sky.last;
  Color get far => ridges.first;
  Color get mid => ridges[2];
  Color get near => ridges.last;
  Color get snow => light;

  /// Whether the light comes from the left.
  bool get lightFromLeft => sunAt.dx < 0.5;

  static const Color mistDay = Color(0xFFEEF2F6);
  static const Color mistNight = Color(0xFF111A35);

  /// The page colour the scenery fades into, for [dark] or day.
  static Color mistFor(bool dark) => dark ? mistNight : mistDay;

  static final Map<(Biome, bool), BiomePalette> _cache = {};

  static BiomePalette of(Biome biome, {required bool dark}) =>
      _cache[(biome, dark)] ??= dark ? _night(biome) : _day(biome);

  static BiomePalette _day(Biome biome) {
    const wall = Color(0xFFF8F4EC);
    const frame = Color(0xFF2A2420);
    const window = Color(0xFF3A3433);
    BiomePalette p({
      required List<Color> sky,
      required Color sun,
      required Color glow,
      required Offset sunAt,
      required Color light,
      required Color snowShade,
      required Color rockShade,
      required Color haze,
      required List<Color> ridges,
      required Color ground,
      required Color groundShade,
      required Color groundLight,
      required Color trail,
      required Color trailEdge,
      Color water = const Color(0xFF7FBFD4),
      Color waterDeep = const Color(0xFF4E95B3),
      Color cloudLit = const Color(0xFFFFFFFF),
      Color cloudShade = const Color(0xFFD5DFEA),
      bool rays = false,
    }) => BiomePalette._(
      biome: biome,
      dark: false,
      mist: mistDay,
      sky: sky,
      sun: sun,
      glow: glow,
      sunAt: sunAt,
      light: light,
      snowShade: snowShade,
      rockShade: rockShade,
      haze: haze,
      ridges: ridges,
      ground: ground,
      groundShade: groundShade,
      groundLight: groundLight,
      trail: trail,
      trailEdge: trailEdge,
      water: water,
      waterDeep: waterDeep,
      cloudLit: cloudLit,
      cloudShade: cloudShade,
      wall: wall,
      frame: frame,
      window: window,
      rays: rays,
    );
    return switch (biome) {
      // Soft morning: warm low light from the left, a pale lilac range.
      Biome.valley => p(
        sky: const [
          Color(0xFF86B1D9),
          Color(0xFFAFCBE4),
          Color(0xFFE2E4E0),
          Color(0xFFF6E7D2),
        ],
        sun: const Color(0xFFFFF6E2),
        glow: const Color(0xFFFFE0B0),
        sunAt: const Offset(0.2, 0.62),
        light: const Color(0xFFFFFBF2),
        snowShade: const Color(0xFFB5C0D9),
        rockShade: const Color(0xFF7D8BAA),
        haze: const Color(0xFFEDE7DD),
        ridges: const [
          Color(0xFFB9C1D6),
          Color(0xFF9EAFC6),
          Color(0xFF8FA796),
          Color(0xFF7E9F68),
          Color(0xFF90AE5E),
        ],
        ground: const Color(0xFF94AF5A),
        groundShade: const Color(0xFF7C984A),
        groundLight: const Color(0xFFB0C674),
        trail: const Color(0xFFEDE0C0),
        trailEdge: const Color(0xFFBFA77A),
        water: const Color(0xFF9CCDE0),
        waterDeep: const Color(0xFF66A6C2),
        cloudShade: const Color(0xFFE2DCE0),
      ),
      // Bright noon: deep blue sky, high white sun, fresh greens.
      Biome.pasture => p(
        sky: const [
          Color(0xFF3B82C4),
          Color(0xFF6AA6D8),
          Color(0xFFB2D3EA),
          Color(0xFFE0EDF2),
        ],
        sun: const Color(0xFFFFFFFF),
        glow: const Color(0xFFFFFBEA),
        sunAt: const Offset(0.86, 0.36),
        light: const Color(0xFFFFFFFF),
        snowShade: const Color(0xFFAFC2DB),
        rockShade: const Color(0xFF6E86A6),
        haze: const Color(0xFFDDEBF1),
        ridges: const [
          Color(0xFFA8BCD4),
          Color(0xFF8AA6C0),
          Color(0xFF6E9C80),
          Color(0xFF5E9350),
          Color(0xFF6FA653),
        ],
        ground: const Color(0xFF73A753),
        groundShade: const Color(0xFF5B8E43),
        groundLight: const Color(0xFF94C16A),
        trail: const Color(0xFFE8DCB4),
        trailEdge: const Color(0xFFB09B6C),
      ),
      // Late afternoon: warm light from the right, a turquoise lake.
      Biome.lake => p(
        sky: const [
          Color(0xFF5B90C2),
          Color(0xFF93B9D8),
          Color(0xFFE6D8C2),
          Color(0xFFF4D4AA),
        ],
        sun: const Color(0xFFFFF2D6),
        glow: const Color(0xFFFFCE90),
        sunAt: const Offset(0.82, 0.66),
        light: const Color(0xFFFFF4E4),
        snowShade: const Color(0xFFA7AFCE),
        rockShade: const Color(0xFF7A7C9E),
        haze: const Color(0xFFF0DCC4),
        ridges: const [
          Color(0xFFB8B4CA),
          Color(0xFFA29CB5),
          Color(0xFFA9957E),
          Color(0xFFB09A74),
          Color(0xFFBDAF80),
        ],
        ground: const Color(0xFFBFB27E),
        groundShade: const Color(0xFFA59868),
        groundLight: const Color(0xFFD4C892),
        trail: const Color(0xFFF1E6C9),
        trailEdge: const Color(0xFFC0AD7E),
        water: const Color(0xFF34B8B0),
        waterDeep: const Color(0xFF13808F),
        cloudLit: const Color(0xFFFFF6EA),
        cloudShade: const Color(0xFFE6CFC0),
      ),
      // Misty morning: cool greens dissolving in mist, light in shafts.
      Biome.forest => p(
        sky: const [
          Color(0xFF98B3C3),
          Color(0xFFBBCED6),
          Color(0xFFDAE4E2),
          Color(0xFFEEF1E9),
        ],
        sun: const Color(0xFFFFFCF0),
        glow: const Color(0xFFF7F1DA),
        sunAt: const Offset(0.2, 0.6),
        light: const Color(0xFFFAFBF6),
        snowShade: const Color(0xFFB4C4CE),
        rockShade: const Color(0xFF6F8A92),
        haze: const Color(0xFFE4ECE8),
        ridges: const [
          Color(0xFFABBEC2),
          Color(0xFF8DA8A8),
          Color(0xFF66907F),
          Color(0xFF46745C),
          Color(0xFF3F6E4D),
        ],
        ground: const Color(0xFF527F4C),
        groundShade: const Color(0xFF3F6A3F),
        groundLight: const Color(0xFF6A955B),
        trail: const Color(0xFFDCCBA2),
        trailEdge: const Color(0xFFA08C62),
        cloudShade: const Color(0xFFD9E3E2),
        rays: true,
      ),
      // Golden hour: apricot sky, alpenglow on the snow, warm ochre.
      Biome.monastery => p(
        sky: const [
          Color(0xFF6B82B6),
          Color(0xFFC29BA8),
          Color(0xFFF0B98C),
          Color(0xFFFAD7A2),
        ],
        sun: const Color(0xFFFFEDC4),
        glow: const Color(0xFFFFB466),
        sunAt: const Offset(0.18, 0.74),
        light: const Color(0xFFFFE4C2),
        snowShade: const Color(0xFFA899BC),
        rockShade: const Color(0xFF7D6886),
        haze: const Color(0xFFF5CCA2),
        ridges: const [
          Color(0xFFB9A3B6),
          Color(0xFFA88E9E),
          Color(0xFFB38A6E),
          Color(0xFFA67A56),
          Color(0xFFB98F60),
        ],
        ground: const Color(0xFFC29E68),
        groundShade: const Color(0xFFA4824F),
        groundLight: const Color(0xFFD9B67E),
        trail: const Color(0xFFF2E2BE),
        trailEdge: const Color(0xFFC1A273),
        cloudLit: const Color(0xFFFFE9CF),
        cloudShade: const Color(0xFFD9A7A2),
        rays: true,
      ),
      // Cool, vast and pale: low ranges, a huge sky, a salt lake.
      Biome.plateau => p(
        sky: const [
          Color(0xFF7CA7D2),
          Color(0xFFA7C4DF),
          Color(0xFFD4E1EB),
          Color(0xFFEDF1F0),
        ],
        sun: const Color(0xFFFFFFFF),
        glow: const Color(0xFFF3F7FF),
        sunAt: const Offset(0.84, 0.46),
        light: const Color(0xFFFFFFFF),
        snowShade: const Color(0xFFC0CADC),
        rockShade: const Color(0xFF9AA3B8),
        haze: const Color(0xFFE6ECEF),
        ridges: const [
          Color(0xFFC6CEDB),
          Color(0xFFB7BFCC),
          Color(0xFFC8B597),
          Color(0xFFC5AD88),
          Color(0xFFCDB98F),
        ],
        ground: const Color(0xFFCBB98C),
        groundShade: const Color(0xFFB7A177),
        groundLight: const Color(0xFFDCCDA2),
        trail: const Color(0xFFF3EBD2),
        trailEdge: const Color(0xFFC8B285),
        water: const Color(0xFFE9F0EE),
        waterDeep: const Color(0xFFC6D8D7),
      ),
      // Crisp blue and white: big snow faces close by.
      Biome.pass => p(
        sky: const [
          Color(0xFF2C6CB6),
          Color(0xFF5B96D1),
          Color(0xFFA6C9E9),
          Color(0xFFDAE8F5),
        ],
        sun: const Color(0xFFFFFFFF),
        glow: const Color(0xFFE6F1FF),
        sunAt: const Offset(0.86, 0.42),
        light: const Color(0xFFFFFFFF),
        snowShade: const Color(0xFFA6BAD8),
        rockShade: const Color(0xFF5E6F90),
        haze: const Color(0xFFDAE7F3),
        ridges: const [
          Color(0xFFB2C5DE),
          Color(0xFF93A9CB),
          Color(0xFF7E90AE),
          Color(0xFFCCD8E7),
          Color(0xFFE2EAF3),
        ],
        ground: const Color(0xFFDDE5EF),
        groundShade: const Color(0xFFC3CFDE),
        groundLight: const Color(0xFFF4F7FB),
        trail: const Color(0xFFBCAF97),
        trailEdge: const Color(0xFF958870),
      ),
    };
  }

  /// Night: a deep indigo sky with stars and the moon, moonlit snow,
  /// dark blue-green ground and lamp-lit windows.
  static BiomePalette _night(Biome biome) {
    final day = _day(biome);
    const sky = [
      Color(0xFF0A1130),
      Color(0xFF131E48),
      Color(0xFF213068),
      Color(0xFF33447C),
    ];
    // Ground per biome, all in the blue-green night family.
    final (ground, groundShade, groundLight) = switch (biome) {
      Biome.valley => (
        const Color(0xFF1D3A3A),
        const Color(0xFF15302F),
        const Color(0xFF285050),
      ),
      Biome.pasture => (
        const Color(0xFF1B3B37),
        const Color(0xFF14302D),
        const Color(0xFF26504A),
      ),
      Biome.lake => (
        const Color(0xFF1F3A44),
        const Color(0xFF172E38),
        const Color(0xFF2B4C56),
      ),
      Biome.forest => (
        const Color(0xFF173430),
        const Color(0xFF112925),
        const Color(0xFF214640),
      ),
      Biome.monastery => (
        const Color(0xFF253A42),
        const Color(0xFF1C2E36),
        const Color(0xFF314B52),
      ),
      Biome.plateau => (
        const Color(0xFF2B3D4A),
        const Color(0xFF22323E),
        const Color(0xFF384E5A),
      ),
      Biome.pass => (
        const Color(0xFF4F6188),
        const Color(0xFF41527A),
        const Color(0xFF6577A0),
      ),
    };
    // Near ranges lean to the ground's hue; far ones to the moonlit air.
    final nearest = Color.lerp(ground, const Color(0xFF0E1A2C), 0.15)!;
    final ridges = [
      const Color(0xFF4A5B90),
      const Color(0xFF3A4A7C),
      Color.lerp(const Color(0xFF2C3D66), nearest, 0.35)!,
      Color.lerp(const Color(0xFF233457), nearest, 0.7)!,
      Color.lerp(ground, groundLight, 0.15)!,
    ];
    return BiomePalette._(
      biome: biome,
      dark: true,
      mist: mistNight,
      sky: sky,
      sun: const Color(0xFFF3F5FC),
      glow: const Color(0xFF9DB0E6),
      sunAt: Offset(day.sunAt.dx, 0.5),
      light: const Color(0xFFD3DEF4),
      snowShade: const Color(0xFF66779F),
      rockShade: const Color(0xFF26315A),
      haze: const Color(0xFF2B3A6C),
      ridges: ridges,
      ground: ground,
      groundShade: groundShade,
      groundLight: groundLight,
      trail:
          biome == Biome.pass
              ? const Color(0xFF7E8094)
              : const Color(0xFF6A7488),
      trailEdge: const Color(0xFF3F4860),
      water: const Color(0xFF2F6688),
      waterDeep: const Color(0xFF1A3F5E),
      cloudLit: const Color(0xFF3E4F84),
      cloudShade: const Color(0xFF243060),
      wall: const Color(0xFFA9B6CF),
      frame: const Color(0xFF12151D),
      window: const Color(0xFFF6C35C),
    );
  }

  /// A prop colour for this palette: [day] as is, or sunk into the night.
  Color tone(Color day, [double depth = 0.6]) =>
      dark
          ? Color.lerp(_grey(day, 0.45), const Color(0xFF101A33), depth)!
          : day;

  static Color _grey(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withSaturation(hsl.saturation * (1 - amount)).toColor();
  }

  @override
  bool operator ==(Object other) =>
      other is BiomePalette && other.biome == biome && other.dark == dark;

  @override
  int get hashCode => Object.hash(biome, dark);
}
