import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../services/feature_flags.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import 'games/flashcards_game.dart';
import 'games/match_pairs_game.dart';
import 'games/picture_pick_game.dart';
import 'games/true_false_game.dart';
import 'games/word_builder_game.dart';
import 'memory_match_game.dart';
import 'speed_quiz_screen.dart';
import '../widgets/content_width.dart';
import '../widgets/leaderboard_entry_points.dart';
import '../widgets/yak_mascot.dart';
import '../widgets/yak_says.dart';

class _Game {
  /// The skill the game trains, shown as a tag on its card.
  final String skill;
  final String title;
  final String description;
  final String emoji;
  final Color color;
  final WidgetBuilder builder;

  const _Game({
    required this.skill,
    required this.title,
    required this.description,
    required this.emoji,
    required this.color,
    required this.builder,
  });
}

/// The Games tab: every practice game, tagged with the skill it trains.
class ExtraGamesScreen extends StatelessWidget {
  const ExtraGamesScreen({super.key, this.enabled});

  /// The `games` kill switch in `GET /v1/config`: when on, the tab shows a
  /// notice instead of the games.
  static const String killSwitch = 'games';

  /// Test seam; the default reads [FeatureFlags].
  final bool? enabled;

  static final List<_Game> _games = [
    _Game(
      skill: 'Listening',
      title: 'Listen & Tap',
      description: 'Hear a word, tap its picture.',
      emoji: '🎧',
      color: AppColors.primary,
      builder: (_) => const ListenAndTapScreen(),
    ),
    _Game(
      skill: 'Reading',
      title: 'Picture Pick',
      description: 'Read a word, tap its picture.',
      emoji: '🖼️',
      color: AppColors.green,
      builder: (_) => const PicturePickScreen(),
    ),
    _Game(
      skill: 'Reading',
      title: 'Match Pairs',
      description: 'Pair each word with its meaning.',
      emoji: '🔗',
      color: AppColors.purple,
      builder: (_) => const MatchPairsScreen(),
    ),
    _Game(
      skill: 'Reading',
      title: 'True or False',
      description: 'Is that the right meaning?',
      emoji: '✅',
      color: AppColors.orange,
      builder: (_) => const TrueOrFalseScreen(),
    ),
    _Game(
      skill: 'Spelling',
      title: 'Word Builder',
      description: 'Put the syllables in order.',
      emoji: '🧩',
      color: AppColors.gold,
      builder: (_) => const WordBuilderScreen(),
    ),
    _Game(
      skill: 'Memory',
      title: 'Flashcards',
      description: 'Flip, check, repeat what you miss.',
      emoji: '🃏',
      color: AppColors.primary,
      builder: (_) => const FlashcardsScreen(),
    ),
    _Game(
      skill: 'Memory',
      title: 'Memory Match',
      description: 'Find the photo and word pairs.',
      emoji: '🧠',
      color: AppColors.purple,
      builder: (_) => const MemoryMatchGame(),
    ),
    _Game(
      skill: 'Speed',
      title: 'Speed Quiz',
      description: 'As many as you can in 60 seconds.',
      emoji: '⚡',
      color: AppColors.orange,
      builder: (_) => const SpeedQuizScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Eight games: two columns on a phone, a 4x2 block on an iPad.
    final columns = Breakpoints.isTablet(context) ? 4 : 2;

    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          'Games',
          style: AppTextStyles.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTokens.ink(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: AppTokens.statusBar(context),
        foregroundColor: AppTokens.ink(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [LeaderboardButton(source: 'games')],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: FeatureFlags.instance.changes,
        builder: (context, _, _) {
          final on = enabled ?? FeatureFlags.instance.isEnabled(killSwitch);
          return on ? _buildGames(context, columns) : _buildOff(context);
        },
      ),
    );
  }

  Widget _buildOff(BuildContext context) {
    return const ContentWidth(
      maxWidth: ContentWidth.reading,
      child: Center(
        child: YakNotice(
          title: 'Games are taking a break',
          body: 'They will be back soon. Lessons and Practice still work.',
          mood: YakMood.sleeping,
        ),
      ),
    );
  }

  Widget _buildGames(BuildContext context, int columns) {
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(
            '${_games.length} games with the words from your lessons. '
            'Every right answer earns XP and keeps your streak.',
            style: AppTextStyles.poppins(
              fontSize: 14,
              color: AppTokens.inkSoft(context),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 150,
            ),
            itemCount: _games.length,
            itemBuilder: (context, index) => _GameCard(game: _games[index]),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final _Game game;

  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${game.title}, ${game.skill} game. ${game.description}',
      excludeSemantics: true,
      child: Material(
        color: AppTokens.tint(game.color, context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          splashColor: game.color.withOpacity(0.12),
          highlightColor: game.color.withOpacity(0.08),
          onTap: () {
            final slug = game.title
                .toLowerCase()
                .replaceAll('&', 'and')
                .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
            Analytics.track('game_selected', {
              'game': slug,
              'skill': game.skill,
            });
            Navigator.push(context, screenRoute('game_$slug', game.builder));
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTokens.surface(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        game.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Scales down rather than overflowing on narrow cards or
                    // with large system text.
                    Expanded(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.surface(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              game.skill,
                              style: AppTextStyles.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTokens.inkSoft(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTokens.ink(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  game.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.poppins(
                    fontSize: 12,
                    height: 1.25,
                    color: AppTokens.inkSoft(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
