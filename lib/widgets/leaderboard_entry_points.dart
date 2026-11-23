import 'package:flutter/material.dart';

import '../models/social.dart';
import '../screens/leaderboard_screen.dart';
import '../services/analytics.dart';
import '../services/feature_flags.dart';
import '../services/social_service.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';
import 'yak_mascot.dart';

/// Opens the weekly board, tagged with where from.
void openLeaderboard(BuildContext context, String source) {
  Analytics.track('leaderboard_opened', {'source': source});
  Navigator.of(context).push(
    screenRoute('leaderboard', (_) => LeaderboardScreen(source: source)),
  );
}

/// The trophy button in the Games tab header. Gone while the `leaderboard`
/// kill switch is on.
class LeaderboardButton extends StatelessWidget {
  const LeaderboardButton({super.key, this.source = 'games'});

  final String source;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FeatureFlags.instance.changes,
      builder: (context, _, child) {
        if (!SocialService.leaderboardEnabled) return const SizedBox.shrink();
        return IconButton(
          tooltip: 'Weekly leaderboard',
          icon: const Icon(Icons.emoji_events_outlined),
          onPressed: () => openLeaderboard(context, source),
        );
      },
    );
  }
}

/// Settings > "Show me on the leaderboard". Saves on the server and goes
/// back if that fails.
class LeaderboardVisibilitySwitch extends StatefulWidget {
  const LeaderboardVisibilitySwitch({super.key, this.service});

  final SocialService? service;

  @override
  State<LeaderboardVisibilitySwitch> createState() =>
      _LeaderboardVisibilitySwitchState();
}

class _LeaderboardVisibilitySwitchState
    extends State<LeaderboardVisibilitySwitch> {
  late final SocialService _service = widget.service ?? SocialService.instance;
  bool _visible = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service.visible().then((v) {
      if (mounted) setState(() => _visible = v);
    });
  }

  Future<void> _change(bool visible) async {
    setState(() {
      _visible = visible;
      _saving = true;
    });
    final ok = await _service.setVisible(visible);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _visible = !visible;
    });
    if (ok) {
      Analytics.track('setting_changed', {
        'setting': 'show_on_leaderboard',
        'value': visible,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save that. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Switch.adaptive(
      value: _visible,
      onChanged: _saving ? null : _change,
      activeColor: Theme.of(context).primaryColor,
    );
  }
}

/// "You finished #12": last week's result, shown once on the first launch
/// of a new week.
Future<void> showWeeklyResultSheet(
  BuildContext context,
  WeeklyResult result,
) {
  Analytics.track('leaderboard_result_shown', {
    'rank': result.rank,
    'xp': result.xp,
    'learners': result.totalLearners,
  });
  final rank = result.rank!;
  final title = rank <= 3 ? 'You finished #$rank!' : 'You finished #$rank';
  final body =
      rank == 1
          ? 'Top of the board last week with ${result.xp} XP. Norbu is doing a little dance.'
          : 'Last week you earned ${result.xp} XP out of ${result.totalLearners} learners. '
              'A new week has started: everyone is back at zero.';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTokens.surface(context),
    builder:
        (sheetContext) => SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    YakMascot(
                      size: 96,
                      mood: rank <= 3 ? YakMood.cheering : YakMood.proud,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(title, style: AppTextStyles.display(sheetContext)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(sheetContext),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          openLeaderboard(context, 'weekly_result');
                        },
                        child: const Text("See this week's board"),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
  );
}
