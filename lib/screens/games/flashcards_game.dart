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

/// Flip through a topic's words; the ones you miss come back around.
class FlashcardsScreen extends StatelessWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameHost(
      title: 'Flashcards',
      tagline:
          'Say the meaning, flip the card, and be honest. Missed cards come back.',
      gameId: 'flashcards',
      minWords: 3,
      loadingMessage: 'Shuffling the deck…',
      builder: (context, round) => FlashcardsGame(round: round),
    );
  }
}

class FlashcardsGame extends StatefulWidget {
  static const int maxCards = 10;

  final GameRound round;

  const FlashcardsGame({super.key, required this.round});

  @override
  State<FlashcardsGame> createState() => _FlashcardsGameState();
}

class _FlashcardsGameState extends State<FlashcardsGame> {
  late final List<GameWord> _queue;
  late final int _deckSize;
  final Set<String> _missed = {};
  bool _flipped = false;
  // Bumped per card shown, so a repeated card still animates in.
  int _cardSerial = 0;

  GameWord get _card => _queue.first;
  int get _known => _deckSize - _queue.length;

  @override
  void initState() {
    super.initState();
    final words = widget.round.words;
    _queue = words.take(min(FlashcardsGame.maxCards, words.length)).toList();
    _deckSize = _queue.length;
    _speakCard();
  }

  void _speakCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<ThemeService>().soundEffectsEnabled) {
        playWord(context, _card);
      }
    });
  }

  void _flip() {
    if (_flipped) return;
    setState(() => _flipped = true);
  }

  void _grade({required bool knewIt}) {
    final card = _queue.removeAt(0);
    if (knewIt) {
      Feedback.play(FeedbackEvent.select, context: context);
    } else {
      _missed.add(card.id);
      _queue.add(card);
    }

    if (_queue.isEmpty) {
      widget.round.onFinished(
        GameResult(correct: _deckSize - _missed.length, total: _deckSize),
      );
      return;
    }
    setState(() {
      _flipped = false;
      _cardSerial++;
    });
    _speakCard();
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Column(
      children: [
        GameProgressHeader(
          step: _known,
          totalSteps: _deckSize,
          score: _known,
          label:
              '${_queue.length} ${_queue.length == 1 ? 'card' : 'cards'} left',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            // Capped so the card keeps a card's proportions on an iPad.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                  maxHeight: 520,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder:
                      (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.96,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                  child: Semantics(
                    key: ValueKey('card-$_cardSerial'),
                    button: !_flipped,
                    label: _flipped ? null : 'Show the meaning',
                    // The fill, border and shadow live on this outer box; the
                    // Material inside is transparent. (A shadow on an unfilled box
                    // shows through it and greys the card.)
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTokens.surface(context),
                        borderRadius: BorderRadius.circular(AppRadius.hero),
                        border: Border.all(
                          color: AppTokens.cardBorder(context),
                        ),
                        boxShadow: AppTokens.shadow(context),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.hero),
                          onTap: _flipped ? null : _flip,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // The picture would give the meaning away, so it
                                // is part of the answer side.
                                if (_flipped && card.hasImage) ...[
                                  Flexible(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 200,
                                        maxHeight: 200,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.card,
                                          ),
                                          child: WordImage(word: card),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    card.tibetan,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.poppins(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: AppTokens.ink(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                WordSpeaker(word: card, size: 26, showVoice: true),
                                const SizedBox(height: 16),
                                if (_flipped) ...[
                                  Text(
                                    card.english,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  RomanisationText(
                                    card.romanisation,
                                    fontSize: 16,
                                  ),
                                ] else
                                  Text(
                                    'Tap to see the meaning',
                                    style: AppTextStyles.poppins(
                                      fontSize: 14,
                                      color: AppTokens.inkSoft(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            height: 56,
            child:
                _flipped
                    ? Row(
                      children: [
                        Expanded(
                          child: _GradeButton(
                            label: 'Still learning',
                            color: AppColors.orange,
                            onTap: () => _grade(knewIt: false),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _GradeButton(
                            label: 'I knew it',
                            color: AppColors.green,
                            onTap: () => _grade(knewIt: true),
                          ),
                        ),
                      ],
                    )
                    : _GradeButton(
                      label: 'Show meaning',
                      color: AppColors.primary,
                      onTap: _flip,
                    ),
          ),
        ),
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GradeButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.alphaBlend(
        color.withOpacity(0.14),
        AppTokens.surface(context),
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            label,
            style: AppTextStyles.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTokens.ink(context),
            ),
          ),
        ),
      ),
    );
  }
}
