import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../theme/app_tokens.dart';

/// How quiz answers are presented for a lesson.
enum QuizMode { words, pictures }

/// Shows a bottom sheet asking the user to pick between learning with
/// English words (Tibetan prompt, English options) or Pictures (image
/// prompt, Tibetan options). Returns null when dismissed.
///
/// The last-used mode is persisted via [ThemeService.quizMode] and
/// highlighted the next time the sheet opens.
Future<QuizMode?> showQuizModePicker(BuildContext context) {
  final themeService = Provider.of<ThemeService>(context, listen: false);
  final lastMode =
      themeService.quizMode == 'pictures' ? QuizMode.pictures : QuizMode.words;

  return showModalBottomSheet<QuizMode>(
    context: context,
    backgroundColor: AppTokens.background(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How do you want to learn?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTokens.ink(sheetContext),
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                mode: QuizMode.words,
                icon: Icons.translate,
                title: 'English words',
                subtitle: 'See a Tibetan word, pick its meaning',
                selected: lastMode == QuizMode.words,
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: QuizMode.pictures,
                icon: Icons.image_outlined,
                title: 'Pictures',
                subtitle: 'See a picture, pick the Tibetan word',
                selected: lastMode == QuizMode.pictures,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ModeCard extends StatelessWidget {
  final QuizMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  const _ModeCard({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color:
          selected
              ? AppTokens.tint(accent, context)
              : AppTokens.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Provider.of<ThemeService>(
            context,
            listen: false,
          ).setQuizMode(mode == QuizMode.pictures ? 'pictures' : 'words');
          Navigator.of(context).pop(mode);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : AppTokens.divider(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 32, color: accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.ink(context),
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTokens.inkSoft(context),
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
