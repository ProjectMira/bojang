import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_style.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';

IconData lessonStyleIcon(LessonStyle style) => switch (style) {
  LessonStyle.mixed => Icons.auto_awesome_rounded,
  LessonStyle.pictures => Icons.image_outlined,
  LessonStyle.words => Icons.translate_rounded,
  LessonStyle.listening => Icons.hearing_rounded,
};

/// Bottom sheet for choosing how lessons ask their questions. The choice is
/// saved to [ThemeService.lessonStyle] and applies to every topic, so
/// opening a lesson never has to ask. Returns the picked style, or null
/// when dismissed.
Future<LessonStyle?> showLessonStylePicker(BuildContext context) {
  final current = Provider.of<ThemeService>(context, listen: false).lessonStyle;

  return showModalBottomSheet<LessonStyle>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTokens.background(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lesson style',
                textAlign: TextAlign.center,
                style: AppTextStyles.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTokens.ink(sheetContext),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Used for every topic. Change it any time.',
                textAlign: TextAlign.center,
                style: AppTextStyles.poppins(
                  fontSize: 13,
                  color: AppTokens.inkSoft(sheetContext),
                ),
              ),
              const SizedBox(height: 16),
              for (final style in LessonStyle.values) ...[
                _StyleCard(style: style, selected: style == current),
                if (style != LessonStyle.values.last)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _StyleCard extends StatelessWidget {
  final LessonStyle style;
  final bool selected;

  const _StyleCard({required this.style, required this.selected});

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color:
            selected
                ? AppTokens.tint(accent, context)
                : AppTokens.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            Provider.of<ThemeService>(
              context,
              listen: false,
            ).setLessonStyle(style);
            Navigator.of(context).pop(style);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: selected ? accent : AppTokens.divider(context),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(lessonStyleIcon(style), size: 28, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            style.title,
                            style: AppTextStyles.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.ink(context),
                            ),
                          ),
                          if (style == LessonStyle.mixed) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTokens.tint(AppColors.green, context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Recommended',
                                style: AppTextStyles.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF3F9400),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        style.subtitle,
                        style: AppTextStyles.poppins(
                          fontSize: 13,
                          color: AppTokens.inkSoft(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
