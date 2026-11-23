import 'dart:math';

import 'package:flutter/material.dart' hide Feedback;
import 'package:provider/provider.dart';

import '../../models/game_word.dart';
import '../../services/feedback.dart';
import '../../services/theme_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/romanisation_text.dart';
import '../../widgets/app_text_style.dart';
import 'game_host.dart';
import 'game_widgets.dart';

/// Is this the right meaning? A fast yes/no round.
class TrueOrFalseScreen extends StatelessWidget {
  const TrueOrFalseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameHost(
      title: 'True or False',
      tagline: 'A Tibetan word and a meaning. Do they belong together?',
      gameId: 'true_or_false',
      loadingMessage: 'Mixing up some meanings…',
      builder: (context, round) => TrueFalseGame(round: round),
    );
  }
}

class TrueFalseGame extends StatefulWidget {
  static const int maxQuestions = 12;

  final GameRound round;
  final Random? random;

  const TrueFalseGame({super.key, required this.round, this.random});

  @override
  State<TrueFalseGame> createState() => _TrueFalseGameState();
}

class _TrueFalseGameState extends State<TrueFalseGame> {
  late final Random _random = widget.random ?? Random();
  late final List<GameWord> _targets;
  int _index = 0;
  int _correct = 0;
  int _streak = 0;

  /// The meaning shown for the current word: its own, or another word's.
  late String _claim;
  bool? _answer;

  GameWord get _target => _targets[_index];
  bool get _claimIsTrue => _claim == _target.english;
  bool get _answered => _answer != null;
  bool get _wasRight => _answer == _claimIsTrue;

  @override
  void initState() {
    super.initState();
    final words = widget.round.words;
    _targets =
        words.take(min(TrueFalseGame.maxQuestions, words.length)).toList();
    _loadQuestion();
  }

  void _loadQuestion() {
    final others =
        widget.round.words.where((w) => w.english != _target.english).toList();
    final showTruth = others.isEmpty || _random.nextBool();
    _claim =
        showTruth
            ? _target.english
            : others[_random.nextInt(others.length)].english;
    _answer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<ThemeService>().soundEffectsEnabled) {
        playWord(context, _target);
      }
    });
  }

  void _respond(bool saysTrue) {
    if (_answered) return;
    final isRight = saysTrue == _claimIsTrue;
    Feedback.answer(isRight, context: context);
    setState(() {
      _answer = saysTrue;
      if (isRight) {
        _correct++;
        _streak++;
      } else {
        _streak = 0;
      }
    });

    Future.delayed(Duration(milliseconds: isRight ? 1100 : 2100), () {
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

  @override
  Widget build(BuildContext context) {
    final verdictColor = _wasRight ? AppColors.green : AppColors.red;
    return Column(
      children: [
        GameProgressHeader(
          step: _index + (_answered ? 1 : 0),
          totalSteps: _targets.length,
          score: _correct,
          label:
              _streak >= 3
                  ? '🔥 $_streak in a row'
                  : 'Card ${_index + 1} of ${_targets.length}',
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTokens.surface(context),
                  borderRadius: BorderRadius.circular(AppRadius.hero),
                  border: Border.all(
                    color:
                        _answered
                            ? verdictColor
                            : AppTokens.cardBorder(context),
                    width: _answered ? 3 : 1,
                  ),
                  boxShadow: AppTokens.shadow(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _target.tibetan,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: AppTokens.ink(context),
                        ),
                      ),
                    ),
                    RomanisationText(_target.romanisation, fontSize: 16),
                    const SizedBox(height: 10),
                    WordSpeaker(word: _target, size: 24, showVoice: true),
                    const SizedBox(height: 14),
                    Text(
                      'means',
                      style: AppTextStyles.poppins(
                        fontSize: 14,
                        color: AppTokens.inkSoft(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _claim,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Fixed height so the card does not jump on answer.
                    SizedBox(
                      height: 48,
                      child:
                          _answered
                              ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _wasRight ? 'Right!' : 'Not quite',
                                    style: AppTextStyles.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _wasRight
                                              ? const Color(0xFF3F9400)
                                              : AppColors.red,
                                    ),
                                  ),
                                  Text(
                                    'It means: ${_target.english}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.poppins(
                                      fontSize: 14,
                                      color: AppTokens.ink(context),
                                    ),
                                  ),
                                ],
                              )
                              : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: _AnswerButton(
                  label: 'False',
                  icon: Icons.close_rounded,
                  color: AppColors.red,
                  onTap: _answered ? null : () => _respond(false),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _AnswerButton(
                  label: 'True',
                  icon: Icons.check_rounded,
                  color: AppColors.green,
                  onTap: _answered ? null : () => _respond(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Color.alphaBlend(
          color.withOpacity(0.14),
          AppTokens.surface(context),
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTokens.ink(context),
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
