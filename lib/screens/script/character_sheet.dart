import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/romanisation.dart';
import '../../models/script/script_chart.dart';
import '../../models/script/stroke_data.dart';
import '../../services/theme_service.dart';
import '../../theme/app_tokens.dart';
import '../../theme/tibetan_type.dart';
import '../../widgets/app_text_style.dart';
import '../../widgets/content_width.dart';
import '../../widgets/reading_voice_pickers.dart';
import '../../widgets/romanisation_text.dart';
import '../../widgets/script/stroke_views.dart';
import '../../widgets/speaker_button.dart';

/// A character's sheet: the letter with its sound, reading, a sound hint,
/// near sounds, the stroke order (consonants) and example words.
Future<void> showCharacterSheet(BuildContext context, ScriptChar item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTokens.background(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (sheetContext) => SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.reading),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: CharacterSheet(item: item),
                ),
              ),
            ),
          ),
        ),
  );
}

class CharacterSheet extends StatelessWidget {
  const CharacterSheet({super.key, required this.item});

  final ScriptChar item;

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<ThemeService>().pronunciationVoice;
    final audio = item.audioFor(voice);
    final ink = AppTokens.ink(context);
    final soft = AppTokens.inkSoft(context);
    final tablet = Breakpoints.isTablet(context);
    final strokes = StrokeData.has(item.char);

    final header = Column(
      children: [
        Text(
          item.shown,
          style: TibetanType.style(size: tablet ? 96 : 80, color: ink),
          semanticsLabel: '${item.shown}, read ${item.reading}',
        ),
        RomanisationText(
          Romanisation(phonetic: item.reading, wylie: item.wylie),
          fontSize: 20,
        ),
        if (audio != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SpeakerButton(url: audio, size: 32),
              VoiceChip(audioUrls: item.audioUrls, source: 'script_sheet'),
            ],
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tablet && strokes)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [header, StrokeAnimation(char: item.char, size: 200)],
          )
        else
          header,
        const SizedBox(height: 16),
        if (item.hint.isNotEmpty) _section(context, 'How it sounds', item.hint),
        if (item.tone.isNotEmpty)
          _section(context, 'Tone', item.tone == 'high' ? 'High tone' : 'Low tone'),
        if (item.nearSounds.isNotEmpty) ...[
          _label(context, 'Sounds close to'),
          Wrap(
            spacing: 10,
            children: [
              for (final c in item.nearSounds)
                Chip(
                  label: Text(c, style: TibetanType.style(size: 24, color: ink)),
                  backgroundColor: AppTokens.surface(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (strokes && !tablet) ...[
          _label(context, 'How to write it (tap to replay)'),
          Center(child: StrokeAnimation(char: item.char)),
          const SizedBox(height: 12),
        ],
        if (item.examples.isNotEmpty) ...[
          _label(context, 'Words with it'),
          for (final e in item.examples)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      children: [
                        Text(e.tibetan, style: TibetanType.style(size: TibetanType.titleSize, color: ink)),
                        Text(
                          [e.reading, e.english].where((s) => s.isNotEmpty).join(' · '),
                          style: AppTextStyles.poppins(fontSize: 14, color: soft),
                        ),
                      ],
                    ),
                  ),
                  // No recording yet: the word is shown without a speaker.
                  if (e.audioFor(voice) case final url?) SpeakerButton(url: url),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTextStyles.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTokens.inkSoft(context),
      ),
    ),
  );

  Widget _section(BuildContext context, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, title),
        Text(body, style: AppTextStyles.poppins(fontSize: 16, color: AppTokens.ink(context))),
      ],
    ),
  );
}
