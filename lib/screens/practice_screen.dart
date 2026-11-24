import 'package:flutter/material.dart';

import '../models/learning_path.dart';
import '../models/lesson_queue.dart';
import '../services/analytics.dart';
import '../services/api_service.dart';
import '../services/feature_flags.dart';
import '../services/learning_path_repository.dart';
import '../theme/app_tokens.dart';
import '../theme/tibetan_type.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/exercise_label_pill.dart';
import '../widgets/yak_mascot.dart';
import '../widgets/yak_says.dart';
import 'level_selection_screen.dart';
import 'quiz_screen.dart';

/// The Practice tab (plan item #18): the words due for review (spaced
/// repetition, FSRS) and the ones the learner got wrong or keeps missing,
/// with one button that builds a review session from them
/// (`GET /learn/review`, `/learn/review/session`; the server orders the
/// session, due words first).
///
/// Without FSRS (an older server, or the `fsrs_review` kill switch on) it
/// shows mistake / weak words only, as before.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.fsrsEnabled, this.clock});

  /// The server config kill switch for spaced repetition.
  static const String killSwitch = 'fsrs_review';

  /// Overrides the kill switch (tests).
  final bool? fsrsEnabled;

  /// Overrides "now" for "Next review in …" (tests).
  final DateTime Function()? clock;

  @override
  State<PracticeScreen> createState() => PracticeScreenState();
}

class PracticeScreenState extends State<PracticeScreen> {
  ReviewSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Called when the tab is shown again, so new mistakes appear.
  Future<void> reload() async {
    final summary = await LearningPathRepository.loadReview();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
    Analytics.track('review_loaded', {
      'words': summary?.wordCount,
      'mistakes': summary?.mistakeCount,
      'weak': summary?.weakCount,
      'offline': summary == null,
      'fsrs': summary != null && _fsrsOn(summary),
      'due': summary?.dueCount,
      'tracked': summary?.trackedCount,
    });
  }

  bool _fsrsOn(ReviewSummary summary) =>
      summary.fsrsEnabled &&
      (widget.fsrsEnabled ??
          FeatureFlags.instance.isEnabled(PracticeScreen.killSwitch));

  Future<void> _start() async {
    final summary = _summary;
    final fsrs = summary != null && _fsrsOn(summary);
    Analytics.track('review_started', {
      'words': summary?.wordCount ?? 0,
      'due': fsrs ? summary.dueCount : 0,
      'fsrs': fsrs,
      'source': 'practice_tab',
    });
    await Navigator.push(
      context,
      screenRoute(
        'quiz',
        (context) => QuizScreen(
          topicFilePath: reviewTopicPath(),
          title: 'Review',
          source: 'practice_tab',
        ),
      ),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          'Practice',
          style: AppTextStyles.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTokens.ink(context),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.ink(context),
        systemOverlayStyle: AppTokens.statusBar(context),
      ),
      body: ContentWidth(
        child:
            _loading
                ? const YakLoader(message: 'Finding words to review…')
                : ValueListenableBuilder<int>(
                  valueListenable: FeatureFlags.instance.changes,
                  builder: (context, _, _) => _buildBody(context),
                ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final summary = _summary;
    if (summary == null) {
      return YakNotice(
        title:
            ApiService().isAuthenticated
                ? 'Can’t reach Bojang'
                : 'Review needs an account',
        body:
            'Your review words come from your lessons. Try again when you’re online.',
        actionLabel: 'Retry',
        onAction: () {
          setState(() => _loading = true);
          reload();
        },
      );
    }
    final fsrs = _fsrsOn(summary);
    final shown = fsrs ? summary : summary.withoutFsrs();
    final nothing =
        fsrs
            ? shown.wordCount == 0 &&
                shown.dueCount == 0 &&
                shown.trackedCount == 0
            : shown.wordCount == 0;
    if (nothing) {
      return YakNotice(
        title: 'Nothing to review yet',
        body: 'Words you miss in lessons come here, so you can fix them later.',
        mood: YakMood.happy,
        actionLabel: 'Go to lessons',
        onAction:
            () => Navigator.push(
              context,
              screenRoute(
                'level_selection',
                (_) => const LevelSelectionScreen(),
              ),
            ),
      );
    }
    final tablet = Breakpoints.isTablet(context);
    final words = fsrs ? shown.allWords : shown.words;
    // Distinct words behind the list: flagged words, plus due words that
    // are not flagged (those beyond the listed ones counted as not flagged).
    final total =
        fsrs
            ? shown.wordCount +
                shown.dueWords.where((w) => w.label == 'due').length +
                (shown.dueCount - shown.dueWords.length).clamp(0, 1 << 30)
            : shown.wordCount;
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xxxl,
        ),
        children: [
          if (fsrs)
            _DueHero(
              summary: shown,
              now: (widget.clock ?? DateTime.now)(),
              onStart: _start,
            )
          else
            _ReviewHero(summary: shown, onStart: _start),
          if (words.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.section),
            Text('Your words', style: AppTextStyles.title(context)),
            const SizedBox(height: AppSpacing.md),
          ],
          if (tablet)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.2,
              children: [for (final w in words) _WordTile(word: w)],
            )
          else
            for (final w in words) ...[
              _WordTile(word: w),
              const SizedBox(height: 10),
            ],
          if (total > words.length)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '+ ${total - words.length} more',
                style: AppTextStyles.caption(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.summary, required this.onStart});

  final ReviewSummary summary;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final hue = AppPalette.saffron;
    final face = dark ? hue.night : hue.face;
    final ink = dark ? AppColors.inkLight : hue.onFace;
    final n = summary.wordCount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: [
          BoxShadow(
            color: dark ? hue.nightTint : hue.lip,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const YakMascot(mood: YakMood.happy, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$n ${n == 1 ? 'word' : 'words'} to review',
                      style: AppTextStyles.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (summary.mistakeCount > 0)
                          '${summary.mistakeCount} to fix',
                        if (summary.weakCount > 0) '${summary.weakCount} weak',
                      ].join(' · '),
                      style: AppTextStyles.poppins(
                        fontSize: 14,
                        color: ink.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const ValueKey('review_start_button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.surface(context),
                foregroundColor: dark ? hue.night : hue.lip,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              onPressed: onStart,
              child: Text(
                'Start review',
                style: AppTextStyles.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The spaced-repetition hero: "N words to review" with Start, or, with
/// nothing due, when the next review comes (and a practice button while
/// mistakes are left to fix). "You're remembering N words" underneath.
class _DueHero extends StatelessWidget {
  const _DueHero({
    required this.summary,
    required this.now,
    required this.onStart,
  });

  final ReviewSummary summary;
  final DateTime now;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final hue = AppPalette.saffron;
    final face = dark ? hue.night : hue.face;
    final ink = dark ? AppColors.inkLight : hue.onFace;
    final due = summary.dueCount;
    final tricky = summary.wordCount;
    final tracked = summary.trackedCount;
    final next = summary.nextDueAt;
    final title =
        due > 0
            ? '$due ${due == 1 ? 'word' : 'words'} to review'
            : 'All caught up';
    final detail =
        due > 0
            ? [
              if (summary.mistakeCount > 0) '${summary.mistakeCount} to fix',
              if (summary.weakCount > 0) '${summary.weakCount} weak',
            ].join(' · ')
            : next != null
            ? 'Next review ${nextReviewPhrase(next, now)}'
            : '';
    final String? action =
        due > 0
            ? 'Start review'
            : tricky > 0
            ? 'Practise $tricky tricky ${tricky == 1 ? 'word' : 'words'}'
            : null;
    return Container(
      key: const ValueKey('review_due_hero'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: face,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: [
          BoxShadow(
            color: dark ? hue.nightTint : hue.lip,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const YakMascot(mood: YakMood.happy, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: AppTextStyles.poppins(
                          fontSize: 15,
                          fontWeight:
                              due > 0 ? FontWeight.w400 : FontWeight.w600,
                          color: ink.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (tracked > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.eco_outlined,
                  size: 18,
                  color: ink.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You’re remembering $tracked ${tracked == 1 ? 'word' : 'words'}',
                    style: AppTextStyles.poppins(
                      fontSize: 14,
                      color: ink.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('review_start_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.surface(context),
                  foregroundColor: dark ? hue.night : hue.lip,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                onPressed: onStart,
                child: Text(
                  action,
                  style: AppTextStyles.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Due" tag for a word that is scheduled for review but neither a
/// mistake nor weak (styled like [ExerciseLabelPill]).
class _DuePill extends StatelessWidget {
  const _DuePill();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    return Semantics(
      label: 'Due for review',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTokens.tint(color, context),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'Due',
              style: AppTextStyles.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTokens.ink(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({required this.word});

  final ReviewWord word;

  @override
  Widget build(BuildContext context) {
    final label = switch (word.label) {
      'mistake' => ExerciseLabel.pastMistake,
      'due' => null,
      _ => ExerciseLabel.weak,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTokens.cardBorder(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  word.tibetan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TibetanType.style(
                    size: TibetanType.bodySize,
                    color: AppTokens.ink(context),
                  ),
                ),
                Text(
                  [
                    word.english,
                    if (word.phonetic.isNotEmpty) word.phonetic,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (label == null)
            const _DuePill()
          else
            ExerciseLabelPill(label: label),
        ],
      ),
    );
  }
}
