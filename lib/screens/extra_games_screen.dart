import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics.dart';
import '../services/feature_flags.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/game_icons.dart';
import '../widgets/leaderboard_entry_points.dart';
import '../widgets/scenery/biome.dart';
import '../widgets/scenery/clouds.dart';
import '../widgets/scenery/landscape.dart';
import '../widgets/scenery/signboard.dart';
import '../widgets/yak_mascot.dart';
import '../widgets/yak_says.dart';
import 'games/flashcards_game.dart';
import 'games/match_pairs_game.dart';
import 'games/picture_pick_game.dart';
import 'games/true_false_game.dart';
import 'games/word_builder_game.dart';
import 'memory_match_game.dart';
import 'speed_quiz_screen.dart';

class _Game {
  /// The skill the game trains (analytics and semantics).
  final String skill;
  final String title;
  final String description;
  final GameGlyph glyph;
  final AppHue hue;
  final WidgetBuilder builder;

  const _Game({
    required this.skill,
    required this.title,
    required this.description,
    required this.glyph,
    required this.hue,
    required this.builder,
  });

  String get slug => title
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

/// One shelf of games that train the same thing.
class _Shelf {
  const _Shelf(this.title, this.skills);
  final String title;
  final Set<String> skills;
}

/// The Games tab: a lake under the snow peaks, today's game on a signboard
/// by the shore, and every game on shelves by what it trains.
class ExtraGamesScreen extends StatelessWidget {
  const ExtraGamesScreen({super.key, this.enabled, this.today});

  /// The `games` kill switch in `GET /v1/config`: when on, the tab shows a
  /// notice instead of the games.
  static const String killSwitch = 'games';

  /// Test seam; the default reads [FeatureFlags].
  final bool? enabled;

  /// Test seam for the day that picks today's game; defaults to now.
  final DateTime? today;

  static final List<_Game> _games = [
    _Game(
      skill: 'Listening',
      title: 'Listen & Tap',
      description: 'Hear a word, tap its picture.',
      glyph: GameGlyph.conch,
      hue: AppPalette.blue,
      builder: (_) => const ListenAndTapScreen(),
    ),
    _Game(
      skill: 'Reading',
      title: 'Picture Pick',
      description: 'Read a word, tap its picture.',
      glyph: GameGlyph.picture,
      hue: AppPalette.green,
      builder: (_) => const PicturePickScreen(),
    ),
    _Game(
      skill: 'Reading',
      title: 'Match Pairs',
      description: 'Pair each word with its meaning.',
      glyph: GameGlyph.pairs,
      hue: AppPalette.lapis,
      builder: (_) => const MatchPairsScreen(),
    ),
    _Game(
      skill: 'Reading',
      title: 'True or False',
      description: 'Is that the right meaning?',
      glyph: GameGlyph.trueFalse,
      hue: AppPalette.saffron,
      builder: (_) => const TrueOrFalseScreen(),
    ),
    _Game(
      skill: 'Spelling',
      title: 'Word Builder',
      description: 'Put the syllables in order.',
      glyph: GameGlyph.syllables,
      hue: AppPalette.yellow,
      builder: (_) => const WordBuilderScreen(),
    ),
    _Game(
      skill: 'Memory',
      title: 'Flashcards',
      description: 'Flip, check, repeat what you miss.',
      glyph: GameGlyph.flashcard,
      hue: AppPalette.blue,
      builder: (_) => const FlashcardsScreen(),
    ),
    _Game(
      skill: 'Memory',
      title: 'Memory Match',
      description: 'Find the photo and word pairs.',
      glyph: GameGlyph.tiles,
      hue: AppPalette.lapis,
      builder: (_) => const MemoryMatchGame(),
    ),
    _Game(
      skill: 'Speed',
      title: 'Speed Quiz',
      description: 'As many as you can in 60 seconds.',
      glyph: GameGlyph.prayerWheel,
      hue: AppPalette.red,
      builder: (_) => const SpeedQuizScreen(),
    ),
  ];

  static const List<_Shelf> _shelves = [
    _Shelf('Listening and reading', {'Listening', 'Reading'}),
    _Shelf('Memory', {'Memory'}),
    _Shelf('Spelling and speed', {'Spelling', 'Speed'}),
  ];

  /// Every game title, in shelf order (for tests and the shelves).
  static List<String> get titles => [for (final g in _games) g.title];

  /// Today's game: a different one each day, the same all day.
  static String featuredTitle(DateTime day) => _featured(day).title;

  static _Game _featured(DateTime day) {
    final start = DateTime(day.year);
    final dayOfYear =
        DateTime(day.year, day.month, day.day).difference(start).inDays;
    return _games[(day.year * 3 + dayOfYear) % _games.length];
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTokens.statusBar(context),
      child: Scaffold(
        backgroundColor: BiomePalette.mistFor(dark),
        body: ValueListenableBuilder<int>(
          valueListenable: FeatureFlags.instance.changes,
          builder: (context, _, _) {
            final on = enabled ?? FeatureFlags.instance.isEnabled(killSwitch);
            return on ? _buildGames(context) : _buildOff(context);
          },
        ),
      ),
    );
  }

  Widget _buildOff(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GamesHeader(count: _games.length, showCount: false),
        const Expanded(
          child: ContentWidth(
            maxWidth: ContentWidth.reading,
            child: Center(
              child: YakNotice(
                title: 'Games are taking a break',
                body:
                    'They will be back soon. Lessons and Practice still work.',
                mood: YakMood.sleeping,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGames(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    final featured = _featured(today ?? DateTime.now());
    final shelves =
        [
          for (final shelf in _shelves)
            (
              shelf,
              [
                for (final g in _games)
                  if (shelf.skills.contains(g.skill) && g != featured) g,
              ],
            ),
        ].where((s) => s.$2.isNotEmpty).toList();

    Widget shelfView((_Shelf, List<_Game>) s) =>
        _ShelfView(title: s.$1.title, games: s.$2);

    final dark = AppTokens.isDark(context);
    return CustomScrollView(
      slivers: [
        // Eight rows: build them all, so every game is in the tree.
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GamesHeader(
                count: _games.length,
                featured: _FeaturedGame(game: featured, wide: tablet),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ContentWidth(
                maxWidth: tablet ? 900 : ContentWidth.standard,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child:
                      tablet && shelves.length > 1
                          ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: shelfView(shelves.first)),
                              const SizedBox(width: AppSpacing.xxl),
                              Expanded(
                                child: Column(
                                  children: [
                                    for (final s in shelves.skip(1)) ...[
                                      shelfView(s),
                                      const SizedBox(
                                        height: AppSpacing.section,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final s in shelves) ...[
                                shelfView(s),
                                const SizedBox(height: AppSpacing.section),
                              ],
                            ],
                          ),
                ),
              ),
            ],
          ),
        ),
        // The shore closes the page, at the bottom however short the list.
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: SizedBox(
                height: tablet ? 170 : 130,
                width: double.infinity,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ShorePainter(
                      palette: BiomePalette.of(Biome.lake, dark: dark),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _openGame(BuildContext context, _Game game, {required bool featured}) {
  Analytics.track('game_selected', {
    'game': game.slug,
    'skill': game.skill,
    'featured': featured,
  });
  Navigator.push(context, screenRoute('game_${game.slug}', game.builder));
}

/// A turquoise lake under the snow peaks, the title in its sky and today's
/// game standing on the shore.
class _GamesHeader extends StatelessWidget {
  const _GamesHeader({
    required this.count,
    this.featured,
    this.showCount = true,
  });

  final int count;
  final Widget? featured;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final tablet = Breakpoints.isTablet(context);
    final palette = BiomePalette.of(Biome.lake, dark: dark);
    final topInset = MediaQuery.paddingOf(context).top;
    final ridgeZone = tablet ? 190.0 : 150.0;
    final skyHeight = topInset + (tablet ? 360.0 : 310.0);
    final ink = dark ? AppColors.inkDark : AppColors.inkLight;
    const floor = 72.0;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: skyHeight,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: SkyPainter(
                      biome: Biome.lake,
                      palette: palette,
                      ridgeZone: ridgeZone,
                      seed: 11,
                    ),
                  ),
                ),
                DriftingClouds(dark: dark, seed: 11, top: 0.45, bottom: 0.6),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: HorizonPainter(
                      biome: Biome.lake,
                      palette: palette,
                      ridgeZone: ridgeZone,
                      seed: 11,
                      trailX: 0,
                      trailWidth: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: skyHeight,
          left: 0,
          right: 0,
          height: floor,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: MistFloorPainter(palette: palette, seed: 3),
            ),
          ),
        ),
        Positioned(
          top: topInset + AppSpacing.lg,
          left: 0,
          right: 0,
          child: ContentWidth(
            maxWidth: tablet ? 900 : ContentWidth.standard,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.gutter, right: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Games',
                            style: AppTextStyles.poppins(
                              fontSize: tablet ? 34 : 30,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              color: ink,
                            ),
                          ),
                        ),
                        if (showCount) ...[
                          const SizedBox(height: AppSpacing.xs),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Text(
                              '$count games, all with the words from your '
                              'lessons. Every right answer earns XP.',
                              style: AppTextStyles.poppins(
                                fontSize: 14,
                                height: 1.4,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconTheme(
                    data: IconThemeData(color: ink),
                    child: const LeaderboardButton(source: 'games'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (featured != null) ...[
              // Today's game stands on the lake shore, below the peaks.
              SizedBox(height: skyHeight - 8),
              ContentWidth(
                maxWidth: tablet ? 760 : ContentWidth.standard,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: featured!,
                ),
              ),
            ] else
              SizedBox(height: skyHeight + floor - 40),
          ],
        ),
      ],
    );
  }
}

/// Today's game on a signboard: its icon, what it is, and Play.
class _FeaturedGame extends StatelessWidget {
  const _FeaturedGame({required this.game, required this.wide});

  final _Game game;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final colors = SignboardColors.of(context);
    final hue = game.hue;
    final face = dark ? hue.night : hue.face;
    final onFace = dark ? AppColors.inkLight : hue.onFace;

    final icon = Container(
      width: wide ? 76 : 64,
      height: wide ? 76 : 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(18),
      ),
      child: GameIcon(game.glyph, color: onFace, size: wide ? 44 : 38),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Today's game",
          style: AppTextStyles.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.inkSoft,
          ),
        ),
        Text(
          game.title,
          style: AppTextStyles.poppins(
            fontSize: wide ? 24 : 21,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          game.description,
          style: AppTextStyles.poppins(
            fontSize: 14,
            height: 1.35,
            color: colors.inkSoft,
          ),
        ),
      ],
    );
    final play = Material(
      color: face,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        key: const ValueKey('featured_game_play'),
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: () => _openGame(context, game, featured: true),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              widthFactor: 1,
              child: Text(
                'Play',
                style: AppTextStyles.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: onFace,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: "Today's game: ${game.title}. ${game.description}",
      child: Signboard(
        child:
            wide
                ? Row(
                  children: [
                    icon,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.lg),
                    play,
                  ],
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        icon,
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: text),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    play,
                  ],
                ),
      ),
    );
  }
}

class _ShelfView extends StatelessWidget {
  const _ShelfView({required this.title, required this.games});

  final String title;
  final List<_Game> games;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTokens.ink(context),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTokens.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border:
                AppTokens.isDark(context)
                    ? Border.all(color: AppTokens.cardBorder(context))
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [for (final g in games) _GameRow(game: g)]),
          ),
        ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game});

  final _Game game;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final hue = game.hue;
    return Semantics(
      button: true,
      label: '${game.title}, ${game.skill} game. ${game.description}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _openGame(context, game, featured: false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTokens.hueTint(hue, context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: GameIcon(
                    game.glyph,
                    color: dark ? hue.night : hue.textOnTint,
                    size: 30,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: AppTextStyles.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.ink(context),
                        ),
                      ),
                      Text(
                        game.description,
                        style: AppTextStyles.poppins(
                          fontSize: 13,
                          height: 1.3,
                          color: SignboardColors.of(context).inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTokens.inkSoft(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
