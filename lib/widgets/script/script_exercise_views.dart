/// Bodies and prompts of the script course exercises in a lesson:
/// build the stack, find the root, near sounds.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/script/script_exercise.dart';
import '../../models/script/stack_builder.dart';
import '../../services/pronunciation_player.dart';
import '../../services/theme_service.dart';
import '../../theme/app_tokens.dart';
import '../../theme/tibetan_type.dart';
import '../app_text_style.dart';

Color _okFill(BuildContext c) => AppTokens.hueTint(AppPalette.green, c);
Color _badFill(BuildContext c) => AppTokens.hueTint(AppPalette.red, c);

/// `build_stack`: one row of choices per slot, a live preview of the built
/// syllable, and Check.
class BuildStackView extends StatefulWidget {
  const BuildStackView({
    super.key,
    required this.payload,
    required this.answered,
    required this.onSubmit,
  });

  final ScriptPayload payload;
  final bool answered;

  /// The built syllable and whether it is the target.
  final void Function(String built, bool correct) onSubmit;

  @override
  State<BuildStackView> createState() => _BuildStackViewState();
}

class _BuildStackViewState extends State<BuildStackView> {
  final Map<StackSlot, String> _choice = {
    StackSlot.prefix: '',
    StackSlot.superscript: '',
    StackSlot.subscript: '',
    StackSlot.vowel: '',
  };

  String get _built => StackBuilder.fromChoices(_choice, tail: widget.payload.tail);

  @override
  Widget build(BuildContext context) {
    final p = widget.payload;
    final correct = p.correctChoices;
    final built = _built;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.surface(context),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTokens.cardBorder(context)),
          ),
          child: Semantics(
            label: built.isEmpty ? 'Nothing built yet' : 'Built: $built',
            child: Text(
              built.isEmpty ? '…' : built,
              style: TibetanType.style(
                size: TibetanType.letterSize,
                color: AppTokens.ink(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final slot in p.slots) ...[
          Text(
            slot.label,
            style: AppTextStyles.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTokens.inkSoft(context),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tile in slot.tiles)
                _TileChip(
                  label: tile.label,
                  tibetan: tile.char.isNotEmpty || slot.slot == StackSlot.vowel,
                  selected: (_choice[slot.slot] ?? '\u0000') == tile.char,
                  state: !widget.answered
                      ? null
                      : (correct[slot.slot] == tile.char ? true : ((_choice[slot.slot] == tile.char) ? false : null)),
                  onTap: widget.answered
                      ? null
                      : () => setState(() => _choice[slot.slot] = tile.char),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (p.tail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Its ending ${p.tail} is already in place.',
              style: AppTextStyles.poppins(fontSize: 13, color: AppTokens.inkSoft(context)),
            ),
          ),
        if (!widget.answered)
          FilledButton(
            onPressed: _choice[StackSlot.root] == null
                ? null
                : () => widget.onSubmit(built, StackBuilder.matches(built, p.target)),
            child: const Text('Check'),
          ),
      ],
    );
  }
}

class _TileChip extends StatelessWidget {
  const _TileChip({
    required this.label,
    required this.tibetan,
    required this.selected,
    required this.onTap,
    this.state,
  });

  final String label;
  final bool tibetan;
  final bool selected;

  /// After answering: true = the right tile, false = picked and wrong.
  final bool? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accent(AppPalette.blue, context);
    final fill = switch (state) {
      true => _okFill(context),
      false => _badFill(context),
      null => selected ? AppTokens.hueTint(AppPalette.blue, context) : AppTokens.surface(context),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'none' ? 'none' : label,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: BorderSide(color: selected ? accent : AppTokens.cardBorder(context), width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: tibetan && label != 'none'
                      ? TibetanType.style(size: 26, color: AppTokens.ink(context))
                      : AppTextStyles.poppins(fontSize: 14, color: AppTokens.ink(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `find_root`: the syllable's consonants as tiles; tap the root. After
/// answering, each tile shows its position.
class FindRootTiles extends StatelessWidget {
  const FindRootTiles({
    super.key,
    required this.payload,
    required this.answered,
    required this.selected,
    required this.correctIndex,
    required this.onPick,
  });

  final ScriptPayload payload;
  final bool answered;
  final int? selected;
  final int correctIndex;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final tiles = payload.rootTiles;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < tiles.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TileChip(
                label: tiles[i].char,
                tibetan: true,
                selected: selected == i,
                state: !answered ? null : (i == correctIndex ? true : (selected == i ? false : null)),
                onTap: answered ? null : () => onPick(i),
              ),
              const SizedBox(height: 4),
              Visibility(
                visible: answered,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(
                  tiles[i].roleLabel,
                  style: AppTextStyles.poppins(fontSize: 11, color: AppTokens.inkSoft(context)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// `near_sound` prompt: plays the clip(s) once on appear (the sound is the
/// question, so it plays even with sound effects off), with replay buttons.
class NearSoundPrompt extends StatefulWidget {
  const NearSoundPrompt({super.key, required this.payload, required this.answered});

  final ScriptPayload payload;
  final bool answered;

  @override
  State<NearSoundPrompt> createState() => _NearSoundPromptState();
}

class _NearSoundPromptState extends State<NearSoundPrompt> {
  int? _playing;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playAll());
  }

  @override
  void didUpdateWidget(NearSoundPrompt old) {
    super.didUpdateWidget(old);
    if (!identical(old.payload, widget.payload)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playAll());
    }
  }

  Future<void> _play(int i) async {
    if (!mounted) return;
    final theme = context.read<ThemeService>();
    final url = widget.payload.clips[i].audioFor(theme.pronunciationVoice);
    setState(() => _playing = i);
    await PronunciationPlayer.instance.play(url, volume: theme.pronunciationVolume, source: 'near_sound');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) setState(() => _playing = null);
  }

  Future<void> _playAll() async {
    final run = ++_run;
    for (var i = 0; i < widget.payload.clips.length; i++) {
      if (!mounted || run != _run) return;
      await _play(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clips = widget.payload.clips;
    final accent = AppTokens.accent(AppPalette.blue, context);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          children: [
            for (var i = 0; i < clips.length; i++)
              Semantics(
                button: true,
                label: clips.length > 1 ? 'Play sound ${i + 1}' : 'Play the sound',
                child: Material(
                  color: AppTokens.hueTint(AppPalette.blue, context),
                  shape: CircleBorder(side: BorderSide(color: _playing == i ? accent : Colors.transparent, width: 3)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _play(i),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volume_up_rounded, color: accent, size: 30),
                          if (clips.length > 1)
                            Text('${i + 1}', style: AppTextStyles.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.answered) ...[
          const SizedBox(height: 12),
          Text(
            clips.map((c) => c.char).join('   '),
            style: TibetanType.style(size: TibetanType.titleSize, color: AppTokens.ink(context)),
          ),
        ],
      ],
    );
  }
}
