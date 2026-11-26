import 'dart:math';

import 'package:flutter/material.dart' hide Feedback;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/game_word.dart';
import '../../services/analytics.dart';
import '../../services/feedback.dart';
import '../../services/game_words_repository.dart';
import '../../services/notification_primer.dart';
import '../../services/pronunciation_player.dart';
import '../../services/progress_service.dart';
import '../../theme/app_tokens.dart';
import '../../services/game_topic_order.dart';
import '../../utils/topic_visuals.dart';
import '../../utils/yak_lines.dart';
import '../../widgets/app_text_style.dart';
import '../../widgets/yak_mascot.dart';
import '../../widgets/yak_says.dart';
import '../streak_celebration_screen.dart';
import 'game_widgets.dart';
import '../../widgets/content_width.dart';

enum _Phase { pickingTopic, loading, playing, finished }

/// The frame every word game shares: pick a topic, load its words, play the
/// round built by [builder], then show the result with XP and a best score.
///
/// A game only has to turn a list of words into a round and report a
/// [GameResult]; everything around it lives here once.
class GameHost extends StatefulWidget {
  final String title;

  /// One line under "Pick a topic" saying what the game asks of the learner.
  final String tagline;

  /// Key for this game's best score in shared preferences and its name in
  /// the progress stats.
  final String gameId;

  /// Fewest usable words a topic must offer for a round to work.
  final int minWords;

  /// Only offer topics whose words all have pictures.
  final bool needsImages;

  /// Which of a topic's words this game can use (e.g. only words with a
  /// recording). Null means all of them.
  final bool Function(GameWord word)? wordFilter;

  final String loadingMessage;
  final Widget Function(BuildContext context, GameRound round) builder;
  final GameWordsRepository repository;

  const GameHost({
    super.key,
    required this.title,
    required this.tagline,
    required this.gameId,
    required this.builder,
    this.minWords = 4,
    this.needsImages = false,
    this.wordFilter,
    this.loadingMessage = 'Getting your words ready…',
    this.repository = const GameWordsRepository(),
  });

  @override
  State<GameHost> createState() => _GameHostState();
}

class _GameHostState extends State<GameHost> {
  _Phase _phase = _Phase.pickingTopic;
  List<GameTopic>? _topics;
  GameTopic? _topic;
  List<GameWord> _words = const [];
  GameResult? _result;
  int _best = 0;
  bool _newBest = false;
  // Rebuilds the game from scratch for every round.
  int _roundId = 0;
  DateTime? _roundStartedAt;

  String get _bestKey => 'game_best_${widget.gameId}';

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _loadBest();
  }

  @override
  void dispose() {
    if (_phase == _Phase.playing) {
      Analytics.track('game_quit', {
        'game': widget.gameId,
        'topic': _topic?.name,
        'duration_s': _roundSeconds(),
      });
    }
    PronunciationPlayer.instance.stop();
    super.dispose();
  }

  int? _roundSeconds() {
    final started = _roundStartedAt;
    return started == null ? null : DateTime.now().difference(started).inSeconds;
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _best = prefs.getInt(_bestKey) ?? 0);
  }

  Future<void> _loadTopics() async {
    setState(() => _topics = null);
    List<GameTopic> topics;
    try {
      topics = await widget.repository.loadTopics();
    } catch (e) {
      debugPrint('Game topics failed to load: $e');
      topics = const [];
    }
    final usable =
        topics
            .where(
              (topic) =>
                  topic.wordCount >= widget.minWords &&
                  (!widget.needsImages || topic.hasImages),
            )
            .toList();
    final ordered = await GameTopicOrder.apply(usable, (t) => t.id);
    if (!mounted) return;
    setState(() => _topics = ordered);
  }

  Future<void> _start(GameTopic topic, {bool random = false}) async {
    GameTopicOrder.played(topic.id);
    Analytics.track('game_topic_selected', {
      'game': widget.gameId,
      'topic': topic.name,
      'topic_id': topic.id,
      'random': random,
    });
    setState(() {
      _phase = _Phase.loading;
      _topic = topic;
    });

    List<GameWord> words;
    try {
      words = await widget.repository.loadWords(topic.id);
    } catch (e) {
      debugPrint('Game words failed to load: $e');
      words = const [];
    }
    if (!mounted) return;

    final filter = widget.wordFilter;
    // A copy: the loaded list may be unmodifiable (an empty result is).
    final usable =
        (filter == null ? words : words.where(filter)).toList()
          ..shuffle(Random());

    if (usable.length < widget.minWords) {
      Analytics.track('game_not_enough_words', {
        'game': widget.gameId,
        'topic': topic.name,
        'usable': usable.length,
        'loaded': words.length,
        'min_words': widget.minWords,
      });
      setState(() => _phase = _Phase.pickingTopic);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            words.isEmpty
                ? 'Could not load words. Check your connection.'
                : '${topic.name} does not have enough words for this game yet. Try another topic.',
          ),
        ),
      );
      return;
    }

    prefetchWordAudio(context, usable);
    precacheWordImages(context, usable);
    _roundStartedAt = DateTime.now();
    Analytics.track('game_started', {
      'game': widget.gameId,
      'topic': topic.name,
      'word_count': usable.length,
    });
    setState(() {
      _words = usable;
      Feedback.startLesson();
      _roundId++;
      _phase = _Phase.playing;
    });
  }

  void _startRandom() {
    final topics = _topics ?? const [];
    if (topics.isEmpty) return;
    _start(topics[Random().nextInt(topics.length)], random: true);
  }

  Future<void> _finish(GameResult result) async {
    if (_phase != _Phase.playing) return;
    PronunciationPlayer.instance.stop();
    Feedback.play(FeedbackEvent.lessonComplete, context: context);
    final newBest = result.correct > _best;
    Analytics.track('game_completed', {
      'game': widget.gameId,
      'topic': _topic?.name,
      'correct': result.correct,
      'total': result.total,
      'accuracy': result.total > 0 ? result.correct / result.total : null,
      'best': newBest ? result.correct : _best,
      'new_best': newBest,
      'duration_s': _roundSeconds(),
    });
    setState(() {
      _result = result;
      _newBest = newBest;
      if (newBest) _best = result.correct;
      _phase = _Phase.finished;
    });

    if (result.total > 0) {
      // Games count toward XP, streak and stats like any other practice.
      await Provider.of<ProgressService>(
        context,
        listen: false,
      ).updateQuizResults(widget.gameId, result.correct, result.total);
    }
    if (newBest) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, result.correct);
    }
    // Last, so nothing above waits on the learner closing it. The primer is
    // a game's only ask, so it follows the celebration directly.
    if (!mounted) return;
    final streak = await StreakCelebrationScreen.showWaiting(context);
    if (streak != null && mounted) {
      await NotificationPrimer.instance.afterStreakCelebration(context, streak);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTextStyles.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTokens.ink(context),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: AppTokens.statusBar(context),
        foregroundColor: AppTokens.ink(context),
      ),
      body: ContentWidth(
        child: SafeArea(
          top: false,
          child: switch (_phase) {
            _Phase.pickingTopic => _buildTopicPicker(context),
            _Phase.loading => YakLoader(message: widget.loadingMessage),
            _Phase.playing => KeyedSubtree(
              key: ValueKey(_roundId),
              child: widget.builder(
                context,
                GameRound(
                  words: _words,
                  topicName: _topic?.name ?? '',
                  onFinished: _finish,
                ),
              ),
            ),
            _Phase.finished => _buildFinished(context),
          },
        ),
      ),
    );
  }

  Widget _buildTopicPicker(BuildContext context) {
    final topics = _topics;
    if (topics == null) {
      return const YakLoader(message: 'Finding topics to play…');
    }
    if (topics.isEmpty) {
      return YakNotice.line(
        YakLines.offline,
        actionLabel: 'Retry',
        onAction: _loadTopics,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('Pick a topic', style: AppTextStyles.display(context)),
        const SizedBox(height: 4),
        Text(
          widget.tagline,
          style: AppTextStyles.poppins(
            fontSize: 14,
            color: AppTokens.inkSoft(context),
          ),
        ),
        if (_best > 0) ...[
          const SizedBox(height: 8),
          Text(
            '🏆 Best: $_best correct',
            style: AppTextStyles.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB8860B),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: _startRandom,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shuffle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Surprise me',
                    style: AppTextStyles.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 64,
          ),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            return Material(
              color: AppTokens.surface(context),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _start(topic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTokens.cardBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        topicEmoji(topic.name),
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTokens.ink(context),
                              ),
                            ),
                            Text(
                              '${topic.wordCount} words',
                              style: AppTextStyles.caption(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFinished(BuildContext context) {
    final result = _result ?? const GameResult(correct: 0, total: 0);
    final accuracy =
        result.total > 0 ? (result.correct / result.total * 100).round() : 0;
    final line = YakLines.gameWon(newBest: _newBest);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            YakMascot(mood: line.mood, size: 160),
            const SizedBox(height: 12),
            Text(
              _newBest ? 'New best score!' : line.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(context),
            ),
            const SizedBox(height: 4),
            Text(
              _topic?.name ?? '',
              style: AppTextStyles.poppins(
                fontSize: 14,
                color: AppTokens.inkSoft(context),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ResultStat(
                  label: 'Correct',
                  value: '${result.correct}/${result.total}',
                  color: AppColors.green,
                ),
                const SizedBox(width: 12),
                _ResultStat(
                  label: 'Accuracy',
                  value: '$accuracy%',
                  color: AppColors.purple,
                ),
                const SizedBox(width: 12),
                _ResultStat(
                  label: 'XP',
                  value: '+${result.correct * 10}',
                  color: AppColors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '🏆 Best: $_best correct',
              style: AppTextStyles.poppins(
                fontSize: 14,
                color: AppTokens.inkSoft(context),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Analytics.track('game_result_action', {
                    'game': widget.gameId,
                    'action': 'play_again',
                  });
                  final topic = _topic;
                  if (topic != null) _start(topic);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(
                  'Play again',
                  style: AppTextStyles.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                Analytics.track('game_result_action', {
                  'game': widget.gameId,
                  'action': 'change_topic',
                });
                setState(() => _phase = _Phase.pickingTopic);
              },
              child: Text(
                'Change topic',
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Analytics.track('game_result_action', {
                  'game': widget.gameId,
                  'action': 'done',
                });
                Navigator.of(context).pop();
              },
              child: Text(
                'Done',
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  color: AppTokens.inkSoft(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppTokens.cardBorder(context)),
        boxShadow: AppTokens.shadow(context),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: AppTextStyles.caption(context)),
        ],
      ),
    );
  }
}
