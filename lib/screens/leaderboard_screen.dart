import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../models/social.dart';
import '../services/analytics.dart';
import '../services/social_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../widgets/learner_avatar.dart';
import '../widgets/profile_setup_sheet.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/yak_mascot.dart';

/// The weekly board (plan #24): everyone's XP since Monday, top 50. The
/// learner's own row is unmistakable (tinted, bold, a "You" chip, their
/// photo), and a "Your rank" bar stays pinned at the bottom whenever that row
/// is off screen or they are outside the top 50. Long-press or the ⋯ button
/// on anyone else's row reports their photo or name, or hides them.
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

  final ScrollController _scroll = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _ownKey = GlobalKey();
  bool _ownOnScreen = true;

  static const double _barHeight = 64;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Whether the learner's own row is (mostly) inside the list's viewport,
  /// above the pinned bar. Rows far off screen are not built at all.
  void _checkOwnRow() {
    final row = _ownKey.currentContext?.findRenderObject();
    final list = _listKey.currentContext?.findRenderObject();
    var onScreen = false;
    if (row is RenderBox &&
        list is RenderBox &&
        row.attached &&
        list.attached) {
      final top = row.localToGlobal(Offset.zero, ancestor: list).dy;
      final bottom = top + row.size.height;
      onScreen =
          top >= -row.size.height / 2 &&
          bottom <= list.size.height - _barHeight + row.size.height / 2;
    }
    if (onScreen != _ownOnScreen && mounted) {
      setState(() => _ownOnScreen = onScreen);
    }
  }

  Future<void> _scrollToOwnRow(WeeklyBoard board) async {
    Analytics.track('leaderboard_my_rank_tapped', {
      'rank': board.me.rank,
      'in_top': board.me.inTop,
    });
    final duration = Motion.read(
      context,
    ).scale(const Duration(milliseconds: 320));
    final ctx = _ownKey.currentContext;
    if (ctx == null && _scroll.hasClients) {
      // Not built yet: jump near it, then settle on it.
      final rank = board.me.rank ?? 0;
      final fraction =
          board.me.inTop && board.entries.isNotEmpty
              ? (rank / board.entries.length).clamp(0.0, 1.0)
              : 1.0;
      _scroll.jumpTo(_scroll.position.maxScrollExtent * fraction);
      await WidgetsBinding.instance.endOfFrame;
    }
    final built = _ownKey.currentContext;
    if (built != null && built.mounted) {
      await Scrollable.ensureVisible(
        built,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
    _checkOwnRow();
  }

  // ── Report / hide ──────────────────────────────────────────────────

  Future<void> _entryActions(WeeklyEntry entry) async {
    if (!entry.canReport) return;
    HapticFeedback.mediumImpact();
    Analytics.track('leaderboard_entry_menu_opened', {'rank': entry.rank});
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppTokens.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: LearnerAvatar(
                  avatar: entry.avatar,
                  photoUrl: entry.photoUrl,
                  size: 40,
                ),
                title: Text(
                  entry.displayName,
                  style: AppTextStyles.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.ink(context),
                  ),
                ),
                subtitle: Text('#${entry.rank} · ${entry.xp} XP'),
              ),
              const Divider(height: 1),
              if (entry.photoUrl != null)
                ListTile(
                  key: const Key('board-report-photo'),
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report photo'),
                  onTap: () => Navigator.of(context).pop('photo'),
                ),
              ListTile(
                key: const Key('board-report-name'),
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report name'),
                onTap: () => Navigator.of(context).pop('name'),
              ),
              ListTile(
                key: const Key('board-hide'),
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide from my board'),
                subtitle: const Text('Only you stop seeing them'),
                onTap: () => Navigator.of(context).pop('hide'),
              ),
              const SizedBox(height: 8),
            ],
          ),
    );
    if (!mounted || action == null) return;
    if (action == 'hide') {
      await _hide(entry);
    } else {
      await _report(entry, action);
    }
  }

  Future<void> _report(WeeklyEntry entry, String kind) async {
    var alsoHide = true;
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppTokens.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheet) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Text(
                        kind == 'photo'
                            ? "What's wrong with this photo?"
                            : "What's wrong with this name?",
                        style: AppTextStyles.title(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Reports are private. We review them, and enough '
                        'reports hide it from everyone straight away.',
                        style: AppTextStyles.caption(context),
                      ),
                    ),
                    for (final r in ReportReason.values)
                      ListTile(
                        key: Key('board-reason-${r.key}'),
                        title: Text(r.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(r),
                      ),
                    CheckboxListTile(
                      key: const Key('board-report-also-hide'),
                      value: alsoHide,
                      onChanged: (v) => setSheet(() => alsoHide = v ?? true),
                      title: const Text('Also hide them from my board'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
          ),
    );
    if (!mounted || reason == null) return;
    final ok = await _service.report(
      entry,
      kind: kind,
      reason: reason,
      hide: alsoHide,
    );
    Analytics.track('leaderboard_report_sent', {
      'kind': kind,
      'reason': reason.key,
      'hide': alsoHide,
      'rank': entry.rank,
      'success': ok,
    });
    if (!mounted) return;
    if (ok && alsoHide) {
      Analytics.track('leaderboard_hidden', {
        'rank': entry.rank,
        'via': 'report',
      });
      setState(() => _board = _board?.without(entry.token));
    }
    _toast(
      ok
          ? 'Thanks for telling us. We\'ll take a look.'
          : "That didn't send. Check your connection and try again.",
    );
  }

  Future<void> _hide(WeeklyEntry entry) async {
    final ok = await _service.hide(entry);
    Analytics.track('leaderboard_hidden', {
      'rank': entry.rank,
      'via': 'menu',
      'success': ok,
    });
    if (!mounted) return;
    if (ok) setState(() => _board = _board?.without(entry.token));
    _toast(
      ok
          ? "${entry.displayName} is hidden from your board."
          : "Couldn't hide them. Check your connection.",
    );
  }

  Future<void> _unhideAll() async {
    final n = await _service.unhideAll();
    Analytics.track('leaderboard_unhidden', {'count': n});
    if (!mounted) return;
    _toast(
      n == null
          ? "Couldn't reach the board. Check your connection."
          : n == 0
          ? "You haven't hidden anyone."
          : 'Showing everyone again.',
    );
    if (n != null && n > 0) _load();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void initState() {
    super.initState();
    _load(first: true);
    // Learners see themselves on the board under their own name and picture.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await maybeAskForProfile(context, 'leaderboard');
      if (saved && mounted) _load();
    });
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOwnRow());
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
            duration: Motion.of(
              context,
            ).scale(const Duration(milliseconds: 220)),
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
    final hasOwnRow = board.me.rank != null && board.me.visible;
    final showBar = hasOwnRow && !_ownOnScreen;
    final tablet = Breakpoints.isTablet(context);
    return Stack(
      key: const ValueKey('board'),
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _checkOwnRow();
            return false;
          },
          child: ListView(
            key: _listKey,
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              4,
              AppSpacing.gutter,
              (tablet ? 48 : 32) + (hasOwnRow ? _barHeight : 0),
            ),
            children: [
              _header(context, board),
              const SizedBox(height: AppSpacing.lg),
              if (!board.me.visible) ...[
                _hiddenNote(context),
                const SizedBox(height: AppSpacing.md),
              ],
              if (board.me.photoHidden) ...[
                _photoHiddenNote(context),
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
                    key: entry.isMe ? _ownKey : null,
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _EntryRow(
                      entry: entry,
                      onActions:
                          entry.canReport ? () => _entryActions(entry) : null,
                    ),
                  ),
              if (ownBelow != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Center(
                    child: Icon(
                      Icons.more_vert,
                      color: AppTokens.inkSoft(context),
                    ),
                  ),
                ),
                KeyedSubtree(key: _ownKey, child: _EntryRow(entry: ownBelow)),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Everyone shares one board. Only your display name, picture '
                'and XP are shown. Press and hold anyone to report or hide '
                'them. You can hide yourself in Settings.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption(context),
              ),
              Center(
                child: TextButton(
                  key: const Key('board-unhide-all'),
                  onPressed: _unhideAll,
                  child: Text(
                    'Show learners I hid',
                    style: AppTextStyles.poppins(
                      fontSize: 13,
                      color: AppTokens.inkSoft(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          bottom: tablet ? 24 : 12,
          child: IgnorePointer(
            ignoring: !showBar,
            child: AnimatedSlide(
              offset: showBar ? Offset.zero : const Offset(0, 1.4),
              duration: Motion.of(
                context,
              ).scale(const Duration(milliseconds: 220)),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: showBar ? 1 : 0,
                duration: Motion.of(
                  context,
                ).scale(const Duration(milliseconds: 180)),
                child: _MyRankBar(
                  board: board,
                  height: _barHeight,
                  onTap: () => _scrollToOwnRow(board),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoHiddenNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTokens.cardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: AppTokens.inkSoft(context),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Your photo is hidden while we review reports. Others see your '
              'drawing instead.',
              style: AppTextStyles.body(context),
            ),
          ),
        ],
      ),
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
          Icon(
            Icons.visibility_off_outlined,
            color: AppTokens.inkSoft(context),
          ),
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
        Text(
          title,
          style: AppTextStyles.title(context),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: AppTextStyles.body(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, this.onActions});

  final WeeklyEntry entry;

  /// Report / hide menu for other learners' rows (null on the learner's own).
  final VoidCallback? onActions;

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
    final accent = AppTokens.accent(AppPalette.blue, context);
    return Semantics(
      label:
          'Rank ${entry.rank}, ${me ? 'you, ' : ''}${entry.displayName}, ${entry.xp} XP',
      excludeSemantics: true,
      customSemanticsActions:
          onActions == null
              ? null
              : {
                const CustomSemanticsAction(label: 'Report or hide'):
                    onActions!,
              },
      child: GestureDetector(
        onLongPress: onActions,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            me ? AppSpacing.md + 2 : AppSpacing.md,
            onActions == null ? AppSpacing.md : AppSpacing.xs,
            me ? AppSpacing.md + 2 : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color:
                me
                    ? AppTokens.hueTint(AppPalette.blue, context)
                    : AppTokens.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: me ? accent : AppTokens.cardBorder(context),
              width: me ? 2.5 : 1,
            ),
            boxShadow:
                me
                    ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
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
              const SizedBox(width: AppSpacing.sm),
              LearnerAvatar(
                avatar: entry.avatar,
                photoUrl: entry.photoUrl,
                size: me ? 44 : 38,
                border: me,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.poppins(
                          fontSize: me ? 16 : 15,
                          fontWeight: me ? FontWeight.w800 : FontWeight.w500,
                          color: AppTokens.ink(context),
                        ),
                      ),
                    ),
                    if (me) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const _YouChip(),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${entry.xp} XP',
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: me ? FontWeight.w800 : FontWeight.w600,
                  color: AppTokens.ink(context),
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              if (onActions != null)
                IconButton(
                  tooltip: 'Report or hide',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.more_horiz,
                    color: AppTokens.inkSoft(context),
                  ),
                  onPressed: onActions,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YouChip extends StatelessWidget {
  const _YouChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'You',
        style: AppTextStyles.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Pinned at the bottom while the learner's own row is off screen.
class _MyRankBar extends StatelessWidget {
  const _MyRankBar({
    required this.board,
    required this.height,
    required this.onTap,
  });

  final WeeklyBoard board;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final me = board.me;
    final own = board.ownEntry ?? board.ownRowBelow;
    return Semantics(
      button: true,
      label: 'Your rank, number ${me.rank}, ${me.xp} XP. Show my row.',
      excludeSemantics: true,
      child: Material(
        key: const Key('board-my-rank-bar'),
        color: AppColors.primary,
        elevation: 6,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  LearnerAvatar(
                    avatar: own?.avatar ?? me.avatar,
                    photoUrl: own?.photoUrl ?? me.photoUrl,
                    size: 38,
                    border: true,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Your rank #${me.rank} · ${me.xp} XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(
                    me.inTop
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
