import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/game_word.dart';
import '../../services/sound_effects.dart';
import '../../services/theme_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_text_style.dart';
import 'game_host.dart';
import 'game_widgets.dart';

/// Tap a Tibetan word, then its meaning. Two boards of five pairs.
class MatchPairsScreen extends StatelessWidget {
  const MatchPairsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameHost(
      title: 'Match Pairs',
      tagline: 'Tap a Tibetan word, then its meaning. Clear the board.',
      gameId: 'match_pairs',
      minWords: MatchPairsGame.pairsPerBoard,
      loadingMessage: 'Laying out the pairs…',
      builder: (context, round) => MatchPairsGame(round: round),
    );
  }
}

class MatchPairsGame extends StatefulWidget {
  static const int pairsPerBoard = 5;
  static const int maxBoards = 2;

  final GameRound round;

  /// Fixed seed for tests; random in the app.
  final Random? random;

  const MatchPairsGame({super.key, required this.round, this.random});

  @override
  State<MatchPairsGame> createState() => _MatchPairsGameState();
}

class _MatchPairsGameState extends State<MatchPairsGame> {
  late final Random _random = widget.random ?? Random();
  late final List<List<GameWord>> _boards;
  int _boardIndex = 0;

  List<GameWord> _left = const [];
  List<GameWord> _right = const [];
  final Set<String> _matched = {};
  // Words already missed once, so a pair only counts as a first-try match
  // when neither side was part of a wrong guess.
  final Set<String> _missed = {};
  String? _selectedLeft;
  String? _selectedRight;
  String? _wrongLeft;
  String? _wrongRight;
  int _firstTry = 0;
  int _pairsDone = 0;

  int get _totalPairs => _boards.fold(0, (sum, board) => sum + board.length);

  @override
  void initState() {
    super.initState();
    final words = widget.round.words;
    const size = MatchPairsGame.pairsPerBoard;
    final boardCount = min(MatchPairsGame.maxBoards, words.length ~/ size);
    _boards = [
      for (var i = 0; i < boardCount; i++)
        words.sublist(i * size, (i + 1) * size),
    ];
    _loadBoard();
  }

  void _loadBoard() {
    final board = _boards[_boardIndex];
    _left = List.of(board)..shuffle(_random);
    _right = List.of(board)..shuffle(_random);
    _matched.clear();
    _selectedLeft = null;
    _selectedRight = null;
  }

  void _tapLeft(GameWord word) {
    if (_matched.contains(word.id) || _wrongLeft != null) return;
    playWord(context, word);
    setState(() => _selectedLeft = word.id);
    _check();
  }

  void _tapRight(GameWord word) {
    if (_matched.contains(word.id) || _wrongLeft != null) return;
    setState(() => _selectedRight = word.id);
    _check();
  }

  void _check() {
    final left = _selectedLeft;
    final right = _selectedRight;
    if (left == null || right == null) return;

    if (left == right) {
      HapticFeedback.lightImpact();
      setState(() {
        _matched.add(left);
        _pairsDone++;
        if (!_missed.contains(left)) _firstTry++;
        _selectedLeft = null;
        _selectedRight = null;
      });
      if (_matched.length == _boards[_boardIndex].length) _boardCleared();
      return;
    }

    SoundEffects.instance.wrong(context.read<ThemeService>());
    setState(() {
      _missed
        ..add(left)
        ..add(right);
      _wrongLeft = left;
      _wrongRight = right;
      _selectedLeft = null;
      _selectedRight = null;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      setState(() {
        _wrongLeft = null;
        _wrongRight = null;
      });
    });
  }

  void _boardCleared() {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_boardIndex < _boards.length - 1) {
        setState(() {
          _boardIndex++;
          _loadBoard();
        });
      } else {
        widget.round.onFinished(
          GameResult(correct: _firstTry, total: _totalPairs),
        );
      }
    });
  }

  TileState _state(GameWord word, {required bool isLeft}) {
    if (_matched.contains(word.id)) return TileState.correct;
    if ((isLeft ? _wrongLeft : _wrongRight) == word.id) return TileState.wrong;
    if ((isLeft ? _selectedLeft : _selectedRight) == word.id) {
      return TileState.selected;
    }
    return TileState.idle;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GameProgressHeader(
          step: _pairsDone,
          totalSteps: _totalPairs,
          score: _firstTry,
          label: 'Board ${_boardIndex + 1} of ${_boards.length}',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final word in _left)
                        Flexible(
                          child: _PairTile(
                            key: ValueKey('left-${word.id}'),
                            text: word.tibetan,
                            isTibetan: true,
                            state: _state(word, isLeft: true),
                            onTap: () => _tapLeft(word),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final word in _right)
                        Flexible(
                          child: _PairTile(
                            key: ValueKey('right-${word.id}'),
                            text: word.english,
                            isTibetan: false,
                            state: _state(word, isLeft: false),
                            onTap: () => _tapRight(word),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PairTile extends StatelessWidget {
  final String text;
  final bool isTibetan;
  final TileState state;
  final VoidCallback onTap;

  const _PairTile({
    super.key,
    required this.text,
    required this.isTibetan,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tileColors(context, state);
    final done = state == TileState.correct;
    // Tiles share the height on a phone but stop growing at a comfortable
    // size, so an iPad shows a compact board instead of five giant rows.
    return Container(
      constraints: const BoxConstraints(maxHeight: 96),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedOpacity(
        opacity: done ? 0.55 : 1,
        duration: const Duration(milliseconds: 250),
        child: Material(
          color: colors.fill,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: done ? null : onTap,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: colors.border, width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppTextStyles.poppins(
                    fontSize: isTibetan ? 22 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
