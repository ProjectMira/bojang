import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics.dart';
import '../services/learner_profile.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';
import 'learner_avatar.dart';

/// Opens the name + picture sheet if the learner has not set them (and has
/// not said "Later" recently). [source] is where it was opened from. True
/// when the learner saved.
Future<bool> maybeAskForProfile(BuildContext context, String source) async {
  final profile = LearnerProfile.instance;
  if (!await profile.shouldAsk()) return false;
  if (!context.mounted) return false;
  if (ModalRoute.of(context)?.isCurrent == false) return false;
  await profile.markAsked();
  if (!context.mounted) return false;
  return showProfileSetupSheet(context, source: source, prompted: true);
}

Future<bool> showProfileSetupSheet(
  BuildContext context, {
  required String source,
  bool prompted = false,
}) async {
  Analytics.track('profile_setup_opened', {
    'source': source,
    'prompted': prompted,
  });
  Analytics.screen('profile_setup');
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppTokens.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ProfileSetupSheet(source: source),
  );
  if (saved != true) {
    Analytics.track('profile_setup_dismissed', {'source': source});
  }
  return saved == true;
}

class ProfileSetupSheet extends StatefulWidget {
  const ProfileSetupSheet({super.key, required this.source});

  final String source;

  @override
  State<ProfileSetupSheet> createState() => _ProfileSetupSheetState();
}

class _ProfileSetupSheetState extends State<ProfileSetupSheet> {
  late final TextEditingController _name;
  late AvatarChoice _choice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = LearnerProfile.instance;
    _name = TextEditingController(text: profile.name ?? '');
    _choice = AvatarChoice.parse(profile.avatar) ?? AvatarChoice.fallback;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    await LearnerProfile.instance.save(name: _name.text, avatar: _choice.key);
    Analytics.track('profile_setup_saved', {
      'source': widget.source,
      'figure': _choice.figure.key,
      'colour': _choice.colour.key,
      'name_length': _name.text.trim().length,
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  void _pick(AvatarChoice choice) {
    if (choice == _choice) return;
    HapticFeedback.selectionClick();
    setState(() => _choice = choice);
    Analytics.track('avatar_option_tapped', {
      'figure': choice.figure.key,
      'colour': choice.colour.key,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.ink(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTokens.cardBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: LearnerAvatarFace(choice: _choice, size: 96)),
                const SizedBox(height: 16),
                Text(
                  'Make it yours',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title(context),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your name and picture show on the weekly leaderboard. '
                  'No account needed.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(context),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('profile-setup-name'),
                  controller: _name,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  style: AppTextStyles.poppins(fontSize: 16, color: ink),
                  decoration: InputDecoration(
                    labelText: 'Your name',
                    hintText: 'e.g. Tenzin',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Picture',
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final f in AvatarFigure.values)
                      _Option(
                        choice: AvatarChoice(f, _choice.colour),
                        selected: f == _choice.figure,
                        onTap: _pick,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final c in AvatarColour.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Semantics(
                          button: true,
                          selected: c == _choice.colour,
                          label: '${c.key} background',
                          child: GestureDetector(
                            onTap: () => _pick(AvatarChoice(_choice.figure, c)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      c == _choice.colour
                                          ? ink
                                          : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('profile-setup-save'),
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _saving ? 'Saving…' : 'Save',
                    style: AppTextStyles.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Later',
                    style: AppTextStyles.poppins(
                      fontSize: 15,
                      color: AppTokens.inkSoft(context),
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

class _Option extends StatelessWidget {
  const _Option({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final AvatarChoice choice;
  final bool selected;
  final ValueChanged<AvatarChoice> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: choice.figure.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTap(choice),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppTokens.ink(context) : Colors.transparent,
              width: 3,
            ),
          ),
          child: LearnerAvatarFace(choice: choice, size: 54),
        ),
      ),
    );
  }
}
