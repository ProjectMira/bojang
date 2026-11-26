import 'package:flutter/material.dart';

import '../models/social.dart';
import '../services/analytics.dart';
import '../services/social_service.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';
import 'leaderboard_entry_points.dart';
import 'learner_avatar.dart';

/// Profile's leaderboard card: where the learner stands this week, the top
/// three, and the way into the full board.
class WeeklyBoardCard extends StatefulWidget {
  const WeeklyBoardCard({super.key, this.loader});

  /// Replaced in tests; defaults to the live weekly board.
  final Future<WeeklyBoard?> Function()? loader;

  @override
  State<WeeklyBoardCard> createState() => WeeklyBoardCardState();
}

class WeeklyBoardCardState extends State<WeeklyBoardCard> {
  WeeklyBoard? _board;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final board = await (widget.loader ?? SocialService.instance.weeklyBoard)();
    if (!mounted) return;
    setState(() {
      _board = board ?? _board;
      _loading = false;
    });
  }

  void _open() {
    Analytics.track('profile_board_card_tapped', {
      'rank': _board?.me.rank,
      'xp': _board?.me.xp,
    });
    openLeaderboard(context, 'profile_card');
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final me = board?.me;
    final top = board?.entries.take(3).toList() ?? const <WeeklyEntry>[];
    final left = board?.timeLeft(DateTime.now());
    final days = left == null ? null : (left.inHours / 24).ceil();
    final headline =
        me?.rank != null
            ? '#${me!.rank}'
            : (me?.visible == false ? 'Hidden' : '—');
    final sub =
        me?.rank != null
            ? 'of ${board!.totalLearners} learners this week'
            : me?.visible == false
            ? 'You chose not to be shown'
            : 'Earn XP in a lesson to join this week';

    return Semantics(
      button: true,
      label:
          'Weekly leaderboard. ${me?.rank != null ? 'You are number ${me!.rank} with ${me.xp} XP.' : sub}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('profile-board-card'),
          onTap: _open,
          borderRadius: BorderRadius.circular(AppRadius.hero),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.hero),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3D49A6), Color(0xFF606CCC)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3D49A6).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.gold,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weekly leaderboard',
                        style: AppTextStyles.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (days != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          days <= 1 ? 'Ends today' : '$days days left',
                          style: AppTextStyles.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _loading && board == null
                        ? const SizedBox(
                          height: 44,
                          width: 44,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          headline,
                          style: AppTextStyles.poppins(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ).copyWith(height: 1.0),
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          board == null && !_loading
                              ? 'Connect to see this week\'s board'
                              : '${me?.xp ?? 0} XP · $sub',
                          style: AppTextStyles.poppins(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final e in top)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${e.rank}',
                              style: AppTextStyles.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:
                                    e.rank == 1 ? AppColors.gold : Colors.white,
                              ),
                            ),
                          ),
                          LearnerAvatar(
                            avatar: e.avatar,
                            photoUrl: e.photoUrl,
                            size: 30,
                            border: true,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.isMe ? '${e.displayName} (you)' : e.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.poppins(
                                fontSize: 14,
                                fontWeight:
                                    e.isMe ? FontWeight.w700 : FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '${e.xp} XP',
                            style: AppTextStyles.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'See the full board',
                    style: AppTextStyles.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3D49A6),
                    ),
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
