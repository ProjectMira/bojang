import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game_word.dart';
import '../../services/sound_effects.dart';
import '../../services/theme_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/romanisation_text.dart';
import '../../widgets/app_text_style.dart';
import 'game_host.dart';
import 'game_widgets.dart';

/// How a [PicturePickGame] gives the learner the word to find.
enum PicturePrompt {
  /// The word is only heard.
  listen,

  /// The word is shown in Tibetan script.
  read,
}

/// Hear a word, tap its picture.
class ListenAndTapScreen extends StatelessWidget {
  const ListenAndTapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameHost(
      title: 'Listen & Tap',
      tagline: 'Hear a Tibetan word, then tap the picture it names.',
      gameId: 'listen_and_tap',
      needsImages: true,
      wordFilter: (word) => word.hasImage && word.hasAudio,
      loadingMessage: 'Warming up the speakers…',
      builder:
          (context, round) =>
              PicturePickGame(round: round, prompt: PicturePrompt.listen),
    );
  }
}

/// Read a Tibetan word, tap its picture.
class PicturePickScreen extends StatelessWidget {
  const PicturePickScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameHost(
      title: 'Picture Pick',
      tagline: 'Read the Tibetan word, then tap the picture it names.',
      gameId: 'picture_pick',
      needsImages: true,
      wordFilter: (word) => word.hasImage,
      loadingMessage: 'Hanging up the pictures…',
      builder:
          (context, round) =>
              PicturePickGame(round: round, prompt: PicturePrompt.read),
    );
  }
}

class PicturePickGame extends StatefulWidget {
  static const int maxQuestions = 10;
  static const int choices = 4;

  final GameRound round;
  final PicturePrompt prompt;
  final Random? random;

  const PicturePickGame({
    super.key,
    required this.round,
    required this.prompt,
    this.random,
  });

  @override
  State<PicturePickGame> createState() => _PicturePickGameState();
}

class _PicturePickGameState extends State<PicturePickGame> {
  late final Random _random = widget.random ?? Random();
  late final List<GameWord> _targets;
  int _index = 0;
  int _correct = 0;
  List<GameWord> _options = const [];
  String? _pickedId;

  GameWord get _target => _targets[_index];
  bool get _answered => _pickedId != null;

  @override
  void initState() {
    super.initState();
    final words = widget.round.words;
    _targets =
        words.take(min(PicturePickGame.maxQuestions, words.length)).toList();
    _loadQuestion();
  }

  void _loadQuestion() {
    final others =
        widget.round.words.where((w) => w.id != _target.id).toList()
          ..shuffle(_random);
    _options = [_target, ...others.take(PicturePickGame.choices - 1)]
      ..shuffle(_random);
    _pickedId = null;
    if (widget.prompt == PicturePrompt.listen) {
      // After the frame, so the first question speaks once the game is up.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) playWord(context, _target);
      });
    }
  }

  void _pick(GameWord word) {
    if (_answered) return;
    final isCorrect = word.id == _target.id;
    final theme = context.read<ThemeService>();
    if (isCorrect) {
      SoundEffects.instance.correct(theme);
    } else {
      SoundEffects.instance.wrong(theme);
    }
    setState(() {
      _pickedId = word.id;
      if (isCorrect) _correct++;
    });
    // In the reading game the word is first heard here, as the answer.
    if (widget.prompt == PicturePrompt.read) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _pickedId != null) playWord(context, _target);
      });
    }

    Future.delayed(Duration(milliseconds: isCorrect ? 1300 : 2000), () {
      if (!mounted) return;
      if (_index < _targets.length - 1) {
        setState(() {
          _index++;
          _loadQuestion();
        });
      } else {
        widget.round.onFinished(
          GameResult(correct: _correct, total: _targets.length),
        );
      }
    });
  }

  TileState _state(GameWord word) {
    if (!_answered) return TileState.idle;
    if (word.id == _target.id) return TileState.correct;
    if (word.id == _pickedId) return TileState.wrong;
    return TileState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final listen = widget.prompt == PicturePrompt.listen;
    return Column(
      children: [
        GameProgressHeader(
          step: _index + (_answered ? 1 : 0),
          totalSteps: _targets.length,
          score: _correct,
          label: 'Word ${_index + 1} of ${_targets.length}',
        ),
        const SizedBox(height: 8),
        Text(
          listen ? 'Tap what you hear' : 'Tap the picture for',
          style: AppTextStyles.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTokens.inkSoft(context),
          ),
        ),
        const SizedBox(height: 8),
        if (listen) ...[
          WordSpeaker(word: _target, size: 44),
          const SizedBox(height: 4),
          // Kept in the layout while hidden so the grid does not jump.
          Visibility(
            visible: _answered,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _PromptWord(word: _target),
          ),
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: _PromptWord(word: _target)),
              const SizedBox(width: 10),
              WordSpeaker(word: _target, size: 22),
            ],
          ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final word in _options)
                        _PictureTile(
                          key: ValueKey('$_index-${word.id}'),
                          word: word,
                          state: _state(word),
                          showLabel: _answered,
                          onTap: () => _pick(word),
                        ),
                    ],
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

class _PromptWord extends StatelessWidget {
  final GameWord word;

  const _PromptWord({required this.word});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              word.tibetan,
              textAlign: TextAlign.center,
              style: AppTextStyles.poppins(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppTokens.ink(context),
              ),
            ),
          ),
          RomanisationText(word.romanisation, fontSize: 15),
        ],
      ),
    );
  }
}

class _PictureTile extends StatelessWidget {
  final GameWord word;
  final TileState state;
  final bool showLabel;
  final VoidCallback onTap;

  const _PictureTile({
    super.key,
    required this.word,
    required this.state,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tileColors(context, state);
    return AnimatedOpacity(
      opacity: state == TileState.dimmed ? 0.45 : 1,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: state == TileState.idle ? onTap : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              WordImage(word: word),
              if (showLabel)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    color: Colors.black.withOpacity(0.6),
                    child: Text(
                      word.english,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: colors.border,
                      width: state == TileState.idle ? 1 : 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
