import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/social.dart';
import '../services/analytics.dart';
import '../services/feature_flags.dart';
import '../services/social_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import 'app_text_style.dart';

/// Family streaks on Profile (plan #26): up to five linked people, the
/// streak each pair shares, and a once-a-day nudge. Invites are codes the
/// other person types in (the app has no deep links). Hidden while the
/// `family` kill switch is on.
class FamilyStreaksCard extends StatelessWidget {
  const FamilyStreaksCard({super.key, this.service});

  final SocialService? service;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FeatureFlags.instance.changes,
      builder: (context, _, child) {
        if (!SocialService.familyEnabled) return const SizedBox.shrink();
        return _FamilyBody(service: service ?? SocialService.instance);
      },
    );
  }
}

class _FamilyBody extends StatefulWidget {
  const _FamilyBody({required this.service});

  final SocialService service;

  @override
  State<_FamilyBody> createState() => _FamilyBodyState();
}

class _FamilyBodyState extends State<_FamilyBody> {
  FamilyState? _family;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final family = await widget.service.family();
    if (!mounted) return;
    setState(() {
      _family = family ?? _family;
      _loaded = true;
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _invite() async {
    if (_busy) return;
    setState(() => _busy = true);
    final invite = await widget.service.createInvite();
    if (!mounted) return;
    setState(() => _busy = false);
    if (invite == null) {
      _snack(
        _family?.isFull == true
            ? 'Your family is full (5 people).'
            : 'Could not make a code. Check your connection.',
      );
      return;
    }
    Analytics.track('family_invite_created', {
      'members': _family?.members.length ?? 0,
    });
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTokens.surface(context),
      builder: (sheet) => _InviteSheet(invite: invite),
    );
  }

  Future<void> _enterCode() async {
    final linked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTokens.surface(context),
      builder: (sheet) => _EnterCodeSheet(service: widget.service),
    );
    if (linked == true) {
      _snack('Linked! Your family streak starts today.');
      await _load();
    }
  }

  Future<void> _nudge(FamilyMember member) async {
    final outcome = await widget.service.nudge(member.linkId);
    if (!mounted) return;
    Analytics.track('family_nudge_sent', {
      'outcome': outcome.name,
      'shared_streak': member.sharedStreak,
    });
    switch (outcome) {
      case NudgeOutcome.sent:
        HapticFeedback.lightImpact();
        _snack('Norbu is on the way to ${member.displayName}.');
      case NudgeOutcome.alreadyNudged:
        _snack('${member.displayName} was nudged today already.');
      case NudgeOutcome.alreadyPractised:
        _snack('${member.displayName} already practised today.');
      case NudgeOutcome.offline:
        _snack('No connection. Try again in a moment.');
        return;
      case NudgeOutcome.failed:
        _snack('That nudge did not go out. Try again later.');
        return;
    }
    await _load();
  }

  Future<void> _remove(FamilyMember member) async {
    final sure = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text('Unlink ${member.displayName}?'),
            content: const Text(
              'Your shared streak ends for both of you. You can link again with a new code.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(
                  'Unlink',
                  style: TextStyle(color: AppTokens.accent(AppPalette.red, dialog)),
                ),
              ),
            ],
          ),
    );
    if (sure != true) return;
    final ok = await widget.service.remove(member.linkId);
    Analytics.track('family_member_removed', {'success': ok});
    if (!mounted) return;
    if (!ok) _snack('Could not unlink. Check your connection.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final family = _family;
    final members = family?.members ?? const <FamilyMember>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Family streaks', style: AppTextStyles.title(context)),
            ),
            if (family != null)
              Text(
                '${members.length}/${family.maxMembers}',
                style: AppTextStyles.caption(context),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Practise on the same days as family and your shared streak grows.',
          style: AppTextStyles.caption(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedSize(
          duration: Motion.of(context).scale(const Duration(milliseconds: 220)),
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              if (!_loaded)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (family == null)
                _note(context, 'Family streaks need a connection.')
              else if (members.isEmpty)
                _note(
                  context,
                  'No one linked yet. Invite a parent, child, sibling or cousin.',
                )
              else
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _MemberRow(
                      member: m,
                      onNudge: () => _nudge(m),
                      onRemove: () => _remove(m),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (family?.isFull != true)
              FilledButton.icon(
                onPressed: _busy ? null : _invite,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Invite family'),
              ),
            OutlinedButton.icon(
              onPressed: family?.isFull == true ? null : _enterCode,
              icon: const Icon(Icons.keyboard, size: 18),
              label: const Text('Enter a code'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _note(BuildContext context, String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppTokens.surface(context),
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppTokens.cardBorder(context)),
    ),
    child: Text(text, style: AppTextStyles.body(context)),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onNudge,
    required this.onRemove,
  });

  final FamilyMember member;
  final VoidCallback onNudge;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final flame = AppTokens.accent(AppPalette.saffron, context);
    final status =
        member.bothDoneToday
            ? 'You both practised today'
            : member.practisedToday
            ? 'They practised today. Your turn!'
            : member.youPractisedToday
            ? 'Waiting for them today'
            : 'Neither of you yet today';
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTokens.cardBorder(context)),
        boxShadow: AppTokens.shadow(context),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Shared streak ${member.sharedStreak} days',
            excludeSemantics: true,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTokens.hueTint(AppPalette.saffron, context),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department, size: 18, color: flame),
                  Text(
                    '${member.sharedStreak}',
                    style: AppTextStyles.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.textOnTint(AppColors.orange, context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink(context),
                  ),
                ),
                Text(status, style: AppTextStyles.caption(context)),
              ],
            ),
          ),
          if (member.canNudge)
            TextButton(onPressed: onNudge, child: const Text('Nudge'))
          else if (member.nudgedToday && !member.practisedToday)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('Nudged', style: AppTextStyles.caption(context)),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert, color: AppTokens.inkSoft(context)),
            onSelected: (_) => onRemove(),
            itemBuilder:
                (_) => const [PopupMenuItem(value: 'remove', child: Text('Unlink'))],
          ),
        ],
      ),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.invite});

  final FamilyInvite invite;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your family code', style: AppTextStyles.title(context)),
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  invite.code,
                  style: AppTextStyles.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.ink(context),
                  ).copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'They open Profile > Family > Enter a code. It works once '
                  'and lasts 7 days.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(context),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Analytics.track('family_invite_shared', {'via': 'share'});
                      Share.share(familyInviteMessage(invite.code));
                    },
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share invite'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: invite.code));
                    Analytics.track('family_invite_shared', {'via': 'copy'});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnterCodeSheet extends StatefulWidget {
  const _EnterCodeSheet({required this.service});

  final SocialService service;

  @override
  State<_EnterCodeSheet> createState() => _EnterCodeSheetState();
}

class _EnterCodeSheetState extends State<_EnterCodeSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.service.acceptInvite(_controller.text);
    if (!mounted) return;
    Analytics.track('family_invite_accepted', {
      'success': error == null,
      'error': error?.name,
    });
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = inviteErrorMessage(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + inset),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter a family code',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink(context),
                  ).copyWith(letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'ABCD-EFGH',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Linking...' : 'Link'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
