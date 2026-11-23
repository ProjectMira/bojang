import 'package:flutter/material.dart';

import '../models/social.dart';
import '../services/analytics.dart';
import '../services/social_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/yak_mascot.dart';

/// The weekly board (plan #24): everyone's XP since Monday, top 50, with
/// the learner's own row pinned underneath when they are further down.
/// Reached from Profile and from the Games tab header; hidden behind the
/// `leaderboard` kill switch.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.source = 'unknown', this.service});

  /// Where it was opened from (profile / games), for analytics.
  final String source;
  final SocialService? service;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final SocialService _service = widget.service ?? SocialService.instance;
  WeeklyBoard? _board;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final board = await _service.weeklyBoard();
    if (!mounted) return;
    setState(() {
      _board = board ?? _board;
      _failed = board == null;
      _loading = false;
    });
    if (first && board != null) {
      Analytics.track('leaderboard_viewed', {
        'source': widget.source,
        'rank': board.me.rank,
        'xp': board.me.xp,
        'in_top': board.me.inTop,
        'visible': board.me.visible,
        'learners': board.totalLearners,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          'This week',
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
      ),
      body: ContentWidth(
        maxWidth: ContentWidth.reading,
        child: RefreshIndicator(
          onRefresh: _load,
          child: AnimatedSwitcher(
            duration: Motion.of(context).scale(const Duration(milliseconds: 220)),
            child:
                board == null
                    ? _placeholder(context)
                    : _boardView(context, board),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ListView(
      key: const ValueKey('placeholder'),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SizedBox(height: 60),
        if (_loading && !_failed)
          const Center(child: CircularProgressIndicator())
        else
          _message(
            context,
            title: 'The board is out of reach',
            body: 'Check your connection and pull down to try again.',
            mood: YakMood.happy,
          ),
      ],
    );
  }

  Widget _boardView(BuildContext context, WeeklyBoard board) {
    final ownBelow = board.ownRowBelow;
    final tablet = Breakpoints.isTablet(context);
    return ListView(
      key: const ValueKey('board'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        4,
        AppSpacing.gutter,
        tablet ? 48 : 32,
      ),
      children: [
        _header(context, board),
        const SizedBox(height: AppSpacing.lg),
        if (!board.me.visible) ...[
          _hiddenNote(context),
          const SizedBox(height: AppSpacing.md),
        ],
        if (board.entries.isEmpty)
          _message(
            context,
            title: 'A fresh week',
            body:
                'Nobody has XP yet this week. One lesson puts you at the top.',
            mood: YakMood.waving,
          )
        else
          for (final entry in board.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _EntryRow(entry: entry),
            ),
        if (ownBelow != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Center(
              child: Icon(Icons.more_vert, color: AppTokens.inkSoft(context)),
            ),
          ),
          _EntryRow(entry: ownBelow),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Everyone shares one board. Only your display name and XP are '
          'shown. You can hide yourself in Settings.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(context),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, WeeklyBoard board) {
    final me = board.me;
    final line =
        me.rank != null
            ? "You're #${me.rank} with ${me.xp} XP"
            : me.visible
            ? 'Finish a lesson to join this week'
            : '${me.xp} XP this week';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTokens.hueTint(AppPalette.yellow, context),
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Row(
        children: [
          const YakMascot(size: 56, showBody: false, mood: YakMood.proud),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line,
                  style: AppTextStyles.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.ink(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${weeklyResetLabel(board.timeLeft(DateTime.now()))} · '
                  '${board.totalLearners} learning this week',
                  style: AppTextStyles.poppins(
                    fontSize: 13,
                    color: AppTokens.textOnTint(AppColors.gold, context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hiddenNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTokens.cardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, color: AppTokens.inkSoft(context)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'You are hidden from the board. Others cannot see you.',
              style: AppTextStyles.body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required String title,
    required String body,
    required YakMood mood,
  }) {
    return Column(
      children: [
        YakMascot(size: 96, mood: mood),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppTextStyles.title(context), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(body, style: AppTextStyles.body(context), textAlign: TextAlign.center),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final WeeklyEntry entry;

  AppHue? get _medal => switch (entry.rank) {
    1 => AppPalette.yellow,
    2 => AppPalette.blue,
    3 => AppPalette.saffron,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final medal = _medal;
    final me = entry.isMe;
    return Semantics(
      label:
          'Rank ${entry.rank}, ${me ? 'you, ' : ''}${entry.displayName}, ${entry.xp} XP',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color:
              me
                  ? AppTokens.hueTint(AppPalette.blue, context)
                  : AppTokens.surface(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color:
                me
                    ? AppTokens.accent(AppPalette.blue, context)
                    : AppTokens.cardBorder(context),
            width: me ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    medal == null
                        ? Colors.transparent
                        : AppTokens.hueTint(medal, context),
              ),
              child: Text(
                '${entry.rank}',
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color:
                      medal == null
                          ? AppTokens.inkSoft(context)
                          : AppTokens.textOnTint(medal.face, context),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                me ? '${entry.displayName} (you)' : entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: me ? FontWeight.w700 : FontWeight.w500,
                  color: AppTokens.ink(context),
                ),
              ),
            ),
            Text(
              '${entry.xp} XP',
              style: AppTextStyles.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTokens.ink(context),
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}
