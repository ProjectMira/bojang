import 'package:bojang/models/learning_path.dart';
import 'package:bojang/screens/extra_games_screen.dart';
import 'package:bojang/widgets/learning_path_view.dart';
import 'package:bojang/widgets/scenery/biome.dart';
import 'package:bojang/widgets/scenery/landscape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/demo_path.dart';

/// The scenery behind the learning path and the Games tab.
void main() {
  group('biomes', () {
    test('one per unit, climbing from the valley to the pass, then again', () {
      expect(
        [for (var i = 1; i <= 8; i++) biomeForUnit(i)],
        [
          Biome.valley,
          Biome.pasture,
          Biome.lake,
          Biome.forest,
          Biome.monastery,
          Biome.plateau,
          Biome.pass,
          Biome.valley,
        ],
      );
      // Odd indexes from the server still land on a biome.
      expect(biomeForUnit(0), Biome.pass);
      expect(biomeForUnit(-6), Biome.valley);
    });

    test('neighbouring units never share a step colour', () {
      for (var i = 1; i <= 14; i++) {
        expect(
          biomeForUnit(i).hue,
          isNot(biomeForUnit(i + 1).hue),
          reason: 'units $i and ${i + 1}',
        );
      }
    });

    test('a unit takes its biome hue', () {
      final path = LearningPath.fromJson(demoPathJson());
      for (final unit in path.units) {
        expect(LearningPathView.hueOf(unit), biomeForUnit(unit.index).hue);
      }
    });

    test('night palettes are darker than day and keep lamp-lit windows', () {
      for (final b in Biome.values) {
        final day = BiomePalette.of(b, dark: false);
        final night = BiomePalette.of(b, dark: true);
        expect(
          night.ground.computeLuminance(),
          lessThan(day.ground.computeLuminance()),
        );
        expect(night.skyHigh.computeLuminance(), lessThan(0.05));
        expect(
          night.window.computeLuminance(),
          greaterThan(day.window.computeLuminance()),
        );
      }
    });
  });

  group('painters repaint only when their input changes', () {
    final day = BiomePalette.of(Biome.lake, dark: false);
    final night = BiomePalette.of(Biome.lake, dark: true);
    TrailLayout layout({int walked = 1}) => TrailLayout(
      centers: const [Offset(100, 80), Offset(160, 220)],
      keepClear: const [Rect.fromLTWH(0, 40, 200, 120)],
      walked: walked,
      trailWidth: 24,
      columnLeft: 0,
      columnRight: 390,
      swing: 70,
      propScale: 1,
    );

    test('sky', () {
      SkyPainter sky({
        Biome biome = Biome.lake,
        BiomePalette? palette,
        int seed = 1,
      }) => SkyPainter(
        biome: biome,
        palette: palette ?? BiomePalette.of(Biome.lake, dark: false),
        ridgeZone: 190,
        seed: seed,
      );
      expect(sky().shouldRepaint(sky()), isFalse);
      expect(sky().shouldRepaint(sky(biome: Biome.pass)), isTrue);
      expect(sky().shouldRepaint(sky(palette: night)), isTrue);
      expect(sky().shouldRepaint(sky(seed: 2)), isTrue);
    });

    test('ground', () {
      final a = GroundPainter(
        biome: Biome.lake,
        palette: day,
        layout: layout(),
        seed: 1,
        fade: 130,
      );
      expect(
        a.shouldRepaint(
          GroundPainter(
            biome: Biome.lake,
            palette: BiomePalette.of(Biome.lake, dark: false),
            layout: layout(),
            seed: 1,
            fade: 130,
          ),
        ),
        isFalse,
      );
      expect(
        a.shouldRepaint(
          GroundPainter(
            biome: Biome.lake,
            palette: night,
            layout: layout(),
            seed: 1,
            fade: 130,
          ),
        ),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          GroundPainter(
            biome: Biome.lake,
            palette: day,
            layout: layout(walked: 2),
            seed: 1,
            fade: 130,
          ),
        ),
        isTrue,
      );
    });
  });

  Future<List<String>> pumpPath(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    bool disableAnimations = false,
    void Function(PathNode)? onOpen,
    void Function(PathNode)? onLocked,
  }) async {
    final events = <String>[];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LearningPathView(
                path: LearningPath.fromJson(demoPathJson()),
                onOpen: onOpen ?? (n) => events.add('open ${n.id}'),
                onLocked: onLocked ?? (n) => events.add('locked ${n.id}'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    return events;
  }

  testWidgets('every unit stands in its own landscape', (tester) async {
    await pumpPath(tester);
    final painters = [
      for (final e in find.byType(CustomPaint).evaluate())
        (e.widget as CustomPaint).painter,
    ];
    final grounds = painters.whereType<GroundPainter>().toList();
    expect(grounds.map((g) => g.biome), Biome.values);
    expect(painters.whereType<SkyPainter>().length, 7);
    expect(painters.whereType<HorizonPainter>().length, 7);
    // Unit 1 is walked to the end; unit 2 up to its active step; the rest
    // are still unwalked.
    expect(grounds[0].layout.walked, 5);
    expect(grounds[1].layout.walked, 3);
    expect(grounds[2].layout.walked, 0);
    expect(find.text('Unit 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('steps stay tappable on the scenery, 48 px or more', (
    tester,
  ) async {
    final events = await pumpPath(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Letters 1')));
    final start = find.byKey(const ValueKey('path_start_button'));
    await tester.ensureVisible(start);
    await tester.pump();
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
    await tester.tap(start);
    final locked = find.bySemanticsLabel(RegExp(r'^Practice, locked'));
    await tester.ensureVisible(locked);
    await tester.pump();
    await tester.tap(locked);
    expect(events, ['open u1-n0', 'open u2-n2', 'locked u2-n3']);
    for (final e in find.byType(PathNodeButton).evaluate()) {
      final size = (e.widget as PathNodeButton).size;
      expect(size, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('nothing moves on its own when motion is off', (tester) async {
    await pumpPath(tester, disableAnimations: true);
    expect(tester.hasRunningAnimations, isFalse);
    final flags =
        [
          for (final e in find.byType(CustomPaint).evaluate())
            (e.widget as CustomPaint).painter,
        ].whereType<WindFlagsPainter>();
    expect(flags, isNotEmpty);
    expect(flags.every((f) => f.wind == null), isTrue);
  });

  testWidgets('at full motion the flags stir in the wind', (tester) async {
    await pumpPath(tester);
    final flags =
        [
          for (final e in find.byType(CustomPaint).evaluate())
            (e.widget as CustomPaint).painter,
        ].whereType<WindFlagsPainter>();
    expect(flags.every((f) => f.wind != null), isTrue);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('night and iPad render without errors', (tester) async {
    await pumpPath(tester, dark: true);
    expect(tester.takeException(), isNull);
    await pumpPath(tester, size: const Size(1024, 1366));
    final ground = tester.getSize(find.byType(LearningPathView));
    expect(ground.width, 1024);
    expect(tester.takeException(), isNull);
  });

  group('Games tab', () {
    Future<void> pumpGames(
      WidgetTester tester, {
      DateTime? today,
      Size size = const Size(390, 2600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: ExtraGamesScreen(enabled: true, today: today)),
      );
      await tester.pump();
    }

    testWidgets('every game is listed once, today\'s on the signboard', (
      tester,
    ) async {
      final day = DateTime(2026, 11, 24);
      await pumpGames(tester, today: day);
      for (final title in ExtraGamesScreen.titles) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(ExtraGamesScreen.titles, hasLength(8));
      final featured = ExtraGamesScreen.featuredTitle(day);
      expect(
        find.descendant(
          of: find.bySemanticsLabel(RegExp("^Today's game: $featured")),
          matching: find.text(featured),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('featured_game_play')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('today\'s game changes from day to day', () {
      final week = {
        for (var d = 1; d <= 8; d++)
          ExtraGamesScreen.featuredTitle(DateTime(2026, 11, d)),
      };
      expect(week, hasLength(8));
      expect(
        ExtraGamesScreen.featuredTitle(DateTime(2026, 11, 24, 8)),
        ExtraGamesScreen.featuredTitle(DateTime(2026, 11, 24, 23)),
      );
    });

    testWidgets('no emoji: every game wears a drawn icon', (tester) async {
      await pumpGames(tester);
      final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      );
      for (final e in find.byType(Text).evaluate()) {
        final data = (e.widget as Text).data ?? '';
        expect(emoji.hasMatch(data), isFalse, reason: data);
      }
    });

    testWidgets('iPad lays the shelves side by side', (tester) async {
      await pumpGames(tester, size: const Size(1024, 1366));
      final left = tester.getRect(find.text('Listening and reading'));
      final right = tester.getRect(find.text('Spelling and speed'));
      expect(right.left, greaterThan(left.right));
      expect(tester.takeException(), isNull);
    });
  });
}
