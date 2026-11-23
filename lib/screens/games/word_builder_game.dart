import 'dart:math';

import 'package:flutter/material.dart' hide Feedback;

import '../../models/game_word.dart';
import '../../services/feedback.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/romanisation_text.dart';
import '../../widgets/app_text_style.dart';
import 'game_host.dart';
import 'game_widgets.dart';

/// Build a Tibetan word from its syllables.
class WordBuilderScreen extends StatelessWidget {
  const WordBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameHost(
      title: 'Word Builder',
      tagline: 'Put the syllables in order to spell the Tibetan word.',
      gameId: 'word_builder',
      wordFilter: WordBuilderGame.canBuild,
      loadingMessage: 'Cutting words into syllables…',
      builder: (context, round) => WordBuilderGame(round: round),
    );
  }
}

class WordBuilderGame extends StatefulWidget {
  static const int maxQuestions = 8;
  static const int _extraTiles = 2;

  /// A word is worth building when there is an order to get right, and it
  /// still fits on one row of slots.
  static bool canBuild(GameWord word) {
    final count = word.syllables.length;
    return count >= 2 && count <= 5;
  }

  final GameRound round;
  final Random? random;

  const WordBuilderGame({super.key, required this.round, this.random});

  @override
  State<WordBuilderGame> createState() => _WordBuilderGameState();
}

enum _BuildState { building, wrong, solved, revealed }

class _WordBuilderGameState extends State<WordBuilderGame> {
  late final Random _random = widget.random ?? Random();
  late final List<GameWord> _targets;
  int _index = 0;
  int _correct = 0;

  /// Syllable tiles on offer: the word's own plus a couple of decoys.
  List<String> _tiles = const [];

  /// For each slot, the index into [_tiles] placed there, or null.
  List<int?> _slots = const [];
  int _attempts = 0;
  _BuildState _state = _BuildState.building;

  GameWord get _target => _targets[_index];
  List<String> get _answer => _target.syllables;

  @override
  void initState() {
    super.initState();
    final words = widget.round.words.where(WordBuilderGame.canBuild).toList();
    _targets =
        words.take(min(WordBuilderGame.maxQuestions, words.length)).toList();
    _loadQuestion();
  }

  void _loadQuestion() {
    final answer = _answer;
    final decoys = <String>[];
    final pool =
        widget.round.words
            .where((w) => w.id != _target.id)
            .expand((w) => w.syllables)
            .where((s) => !answer.contains(s))
            .toSet()
            .toList()
          ..shuffle(_random);
    decoys.addAll(pool.take(WordBuilderGame._extraTiles));

    _tiles = [...answer, ...decoys]..shuffle(_random);
    _slots = List<int?>.filled(answer.length, null);
    _attempts = 0;
    _state = _BuildState.building;
  }

  void _placeTile(int tileIndex) {
    if (_state != _BuildState.building || _slots.contains(tileIndex)) return;
    final slot = _slots.indexOf(null);
    if (slot < 0) return;
    setState(() => _slots[slot] = tileIndex);
    if (!_slots.contains(null)) _check();
  }

  void _clearSlot(int slot) {
    if (_state != _BuildState.building || _slots[slot] == null) return;
    setState(() => _slots[slot] = null);
  }

  void _check() {
    final answer = _answer;
    final built = [for (final tile in _slots) _tiles[tile!]];
    var isCorrect = true;
    for (var i = 0; i < answer.length; i++) {
      if (built[i] != answer[i]) isCorrect = false;
    }

    if (isCorrect) {
      Feedback.answer(true, context: context);
      setState(() {
        _state = _BuildState.solved;
        if (_attempts == 0) _correct++;
      });
      _speakThenAdvance(const Duration(milliseconds: 1500));
      return;
    }

    Feedback.answer(false, context: context);
    _attempts++;
    setState(() => _state = _BuildState.wrong);
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      if (_attempts >= 2) {
        // Two misses: show the word rather than leave the learner stuck.
        setState(() {
          _slots = [
            for (var i = 0; i < answer.length; i++) _tileFor(answer, i),
          ];
          _state = _BuildState.revealed;
        });
        _speakThenAdvance(const Duration(milliseconds: 2200));
      } else {
        setState(() {
          _slots = List<int?>.filled(answer.length, null);
          _state = _BuildState.building;
        });
      }
    });
  }

  /// A tile index holding the answer's [position]-th syllable, giving each
  /// repeated syllable its own tile.
  int _tileFor(List<String> answer, int position) {
    final earlier =
        answer.take(position).where((s) => s == answer[position]).length;
    var seen = 0;
    for (var i = 0; i < _tiles.length; i++) {
      if (_tiles[i] != answer[position]) continue;
      if (seen == earlier) return i;
      seen++;
    }
    return 0;
  }

  void _speakThenAdvance(Duration wait) {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) playWord(context, _target);
    });
    Future.delayed(wait, () {
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

  TileState get _slotState => switch (_state) {
    _BuildState.building => TileState.selected,
    _BuildState.wrong => TileState.wrong,
    _BuildState.solved || _BuildState.revealed => TileState.correct,
  };

  @override
  Widget build(BuildContext context) {
    final done = _state == _BuildState.solved || _state == _BuildState.revealed;
    return Column(
      children: [
        GameProgressHeader(
          step: _index + (done ? 1 : 0),
          totalSteps: _targets.length,
          score: _correct,
          label: 'Word ${_index + 1} of ${_targets.length}',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                if (_target.hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: WordImage(word: _target),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  _target.english,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTokens.ink(context),
                  ),
                ),
                RomanisationText(_target.romanisation, fontSize: 15),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var slot = 0; slot < _slots.length; slot++)
                      _SyllableTile(
                        key: ValueKey('slot-$_index-$slot'),
                        text: _slots[slot] == null ? '' : _tiles[_slots[slot]!],
                        state:
                            _slots[slot] == null ? TileState.idle : _slotState,
                        dashed: _slots[slot] == null,
                        onTap: () => _clearSlot(slot),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child:
                      done
                          ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _state == _BuildState.solved
                                    ? 'ལེགས་སོ། That is it.'
                                    : 'It is spelled like this.',
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTokens.inkSoft(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              WordSpeaker(word: _target, size: 20),
                            ],
                          )
                          : null,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var tile = 0; tile < _tiles.length; tile++)
                      _SyllableTile(
                        key: ValueKey('tile-$_index-$tile'),
                        text: _tiles[tile],
                        state:
                            _slots.contains(tile)
                                ? TileState.dimmed
                                : TileState.idle,
                        hidden: _slots.contains(tile),
                        onTap: () => _placeTile(tile),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SyllableTile extends StatelessWidget {
  final String text;
  final TileState state;
  final bool dashed;
  final bool hidden;
  final VoidCallback onTap;

  const _SyllableTile({
    super.key,
    required this.text,
    required this.state,
    required this.onTap,
    this.dashed = false,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tileColors(context, state);
    return Opacity(
      opacity: hidden ? 0.25 : 1,
      child: Material(
        color: dashed ? Colors.transparent : colors.fill,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: hidden ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 58, minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color:
                    dashed
                        ? AppTokens.inkSoft(context).withOpacity(0.45)
                        : colors.border,
                width: 2,
              ),
            ),
            // Shrink-wrapped: a Container with `alignment` would stretch each
            // tile to the full row.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                text,
                style: AppTextStyles.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
