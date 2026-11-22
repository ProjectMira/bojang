import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_word.dart';
import '../../services/pronunciation_player.dart';
import '../../services/theme_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_text_style.dart';
import '../../widgets/reading_voice_pickers.dart';
import '../../widgets/speaker_button.dart';

/// What a finished round reports back to its [GameHost].
class GameResult {
  /// Answers that were right on the first try.
  final int correct;

  /// Answers attempted.
  final int total;

  const GameResult({required this.correct, required this.total});
}

/// Everything a game needs for one round.
class GameRound {
  final List<GameWord> words;
  final String topicName;
  final ValueChanged<GameResult> onFinished;

  const GameRound({
    required this.words,
    required this.topicName,
    required this.onFinished,
  });
}

/// The word's recording in the learner's chosen voice, if it has one.
String? wordAudio(BuildContext context, GameWord word) {
  return word.audioFor(context.read<ThemeService>().pronunciationVoice);
}

/// Speaks [word] in the learner's chosen voice and volume. Silent when the
/// word has no recording.
void playWord(BuildContext context, GameWord word) {
  final theme = context.read<ThemeService>();
  PronunciationPlayer.instance.play(
    word.audioFor(theme.pronunciationVoice),
    volume: theme.pronunciationVolume,
  );
}

/// Starts downloading every word's recording so it plays without a wait.
void prefetchWordAudio(BuildContext context, Iterable<GameWord> words) {
  final voice = context.read<ThemeService>().pronunciationVoice;
  PronunciationPlayer.instance.prefetch(words.map((w) => w.audioFor(voice)));
}

/// Starts downloading every word's picture, so a round's tiles appear
/// filled instead of popping in one by one. Failures are ignored here; the
/// tile itself falls back to the word's meaning.
void precacheWordImages(BuildContext context, Iterable<GameWord> words) {
  for (final word in words) {
    final url = word.imageUrl;
    if (url == null) continue;
    precacheImage(NetworkImage(url), context, onError: (_, __) {});
  }
}

/// Speaker button for [word], or nothing when it has no recording.
class WordSpeaker extends StatelessWidget {
  final GameWord word;
  final double size;

  /// Also show the voice chip, so the dialect can be changed in the game.
  final bool showVoice;

  const WordSpeaker({
    super.key,
    required this.word,
    this.size = 28,
    this.showVoice = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = word.audioFor(context.watch<ThemeService>().pronunciationVoice);
    if (url == null) return const SizedBox.shrink();
    final speaker = SpeakerButton(url: url, size: size);
    if (!showVoice) return speaker;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        speaker,
        VoiceChip(audioUrls: word.audioUrls, source: 'game'),
      ],
    );
  }
}

/// A word's picture. Falls back to its English meaning when the word has no
/// picture or it fails to load, so a tile is never blank.
class WordImage extends StatelessWidget {
  final GameWord word;
  final BoxFit fit;

  const WordImage({super.key, required this.word, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          word.english,
          textAlign: TextAlign.center,
          style: AppTextStyles.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTokens.ink(context),
          ),
        ),
      ),
    );
    final url = word.imageUrl;
    if (url == null) return fallback;
    return Semantics(
      image: true,
      label: word.english,
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

/// Top strip shared by the games: how far through the round, and the score.
class GameProgressHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final int score;
  final String? label;

  const GameProgressHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.score,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        totalSteps == 0 ? 0.0 : (step / totalSteps).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label ?? '${step.clamp(0, totalSteps)} of $totalSteps',
                  style: AppTextStyles.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.inkSoft(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTokens.tint(AppColors.primary, context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $score',
                  style: AppTextStyles.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppTokens.divider(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How an answer tile should look once the learner has answered.
enum TileState { idle, selected, correct, wrong, dimmed }

/// Fill and border for a tile in [state], correct in light and dark mode.
({Color fill, Color border}) tileColors(BuildContext context, TileState state) {
  Color solid(Color accent, double opacity) =>
      Color.alphaBlend(accent.withOpacity(opacity), AppTokens.surface(context));
  return switch (state) {
    TileState.idle => (
      fill: AppTokens.surface(context),
      border: AppTokens.divider(context),
    ),
    TileState.selected => (
      fill: solid(AppColors.primary, 0.14),
      border: AppColors.primary,
    ),
    TileState.correct => (
      fill: solid(AppColors.green, 0.20),
      border: AppColors.green,
    ),
    TileState.wrong => (
      fill: solid(AppColors.red, 0.18),
      border: AppColors.red,
    ),
    TileState.dimmed => (
      fill: AppTokens.surface(context).withOpacity(0.5),
      border: AppTokens.divider(context),
    ),
  };
}
