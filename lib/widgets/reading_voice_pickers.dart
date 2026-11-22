import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/romanisation.dart';
import '../services/analytics.dart';
import '../services/pronunciation_voices.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';
import 'content_width.dart';

Future<T?> _sheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTokens.background(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (sheetContext) => SafeArea(
          // Sized to its content (not full height), and no wider than a
          // reading column on iPad.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.reading),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: builder(sheetContext),
              ),
            ),
          ),
        ),
  );
}

Widget _sheetTitle(BuildContext context, String title, String subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: AppTextStyles.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTokens.ink(context),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: AppTextStyles.poppins(fontSize: 13, color: AppTokens.ink(context)),
      ),
      const SizedBox(height: 16),
    ],
  );
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final Widget? leading;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.enabled = true,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.primary : AppTokens.cardBorder(context);
    final ink = enabled ? AppTokens.ink(context) : AppTokens.inkSoft(context);
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Material(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.poppins(fontSize: 13, color: ink),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the learner choose how Tibetan is romanised next to the script.
Future<void> showTransliterationPicker(BuildContext context) {
  return _sheet(context, (sheetContext) {
    final theme = sheetContext.watch<ThemeService>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sheetTitle(
          sheetContext,
          'Reading help',
          'Shown under Tibetan words. Turn it off as you learn the script.',
        ),
        for (final mode in TransliterationMode.values) ...[
          _OptionCard(
            title: mode.title,
            subtitle: mode.subtitle,
            selected: theme.transliterationMode == mode,
            onTap: () {
              theme.setTransliterationMode(mode);
              Navigator.of(sheetContext).pop();
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  });
}

/// Lets the learner choose the voice (and so the dialect) of pronunciation
/// recordings. [available] are the voices the current word has; a voice it
/// lacks is still selectable and says which voice will play instead.
Future<void> showVoicePicker(
  BuildContext context, {
  Set<String> available = const {},
  String source = 'settings',
}) {
  return _sheet(context, (sheetContext) {
    final theme = sheetContext.watch<ThemeService>();
    final children = <Widget>[
      _sheetTitle(
        sheetContext,
        'Pronunciation voice',
        'Hear words in the dialect you want to learn.',
      ),
    ];
    for (final dialect in TibetanDialect.values) {
      final voices =
          PronunciationVoices.all.where((v) => v.dialect == dialect).toList();
      if (voices.isEmpty) {
        children
          ..add(
            _OptionCard(
              title: dialect.label,
              subtitle: '${dialect.region} · coming soon',
              selected: false,
              enabled: false,
              leading: const Icon(Icons.schedule),
            ),
          )
          ..add(const SizedBox(height: 10));
        continue;
      }
      for (final voice in voices) {
        var subtitle = '${dialect.region} · ${voice.speaker} voice';
        if (available.isNotEmpty && !available.contains(voice.id)) {
          final fallback = PronunciationVoices.byId(
            PronunciationVoices.resolve({
              for (final id in available) id: '',
            }, voice.id),
          );
          if (fallback != null) {
            subtitle = 'Not recorded for this word yet, plays ${fallback.label}';
          }
        }
        children
          ..add(
            _OptionCard(
              title: voice.label,
              subtitle: subtitle,
              selected: theme.pronunciationVoice == voice.id,
              leading: const Icon(Icons.record_voice_over),
              onTap: () {
                Analytics.track('voice_picked', {
                  'voice': voice.id,
                  'source': source,
                });
                theme.setPronunciationVoice(voice.id);
                Navigator.of(sheetContext).pop();
              },
            ),
          )
          ..add(const SizedBox(height: 10));
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  });
}

/// Small chip naming the voice a word plays in ("Lhasa ♀"). Tapping it opens
/// [showVoicePicker], so the dialect can be changed where audio is played.
class VoiceChip extends StatelessWidget {
  /// The current word's per-voice recordings (`audio_urls`), used to show
  /// the voice that will really play when the chosen one is missing.
  final Map<String, String> audioUrls;
  final String source;

  const VoiceChip({super.key, this.audioUrls = const {}, this.source = 'chip'});

  @override
  Widget build(BuildContext context) {
    final preferred = context.watch<ThemeService>().pronunciationVoice;
    // With no word in view the chip names the learner's choice; with a word
    // it names the voice that word will really play in.
    final used =
        audioUrls.isEmpty
            ? preferred
            : PronunciationVoices.resolve(audioUrls, preferred) ?? preferred;
    final voice =
        PronunciationVoices.byId(used) ?? PronunciationVoices.all.first;
    final color = AppTokens.ink(context);
    return Semantics(
      button: true,
      label: 'Voice: ${voice.label}. Change voice',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap:
            () => showVoicePicker(
              context,
              available: audioUrls.keys.toSet(),
              source: source,
            ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTokens.cardBorder(context)),
            color: AppTokens.surface(context),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.record_voice_over, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                voice.shortLabel,
                style: AppTextStyles.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Icon(Icons.expand_more, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
