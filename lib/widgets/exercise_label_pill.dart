import 'package:flutter/material.dart';

import '../models/lesson_queue.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';

/// Small tag above a question saying why it is here: a new word, a mistake
/// to fix, a weak word or a hard bonus question.
class ExerciseLabelPill extends StatelessWidget {
  const ExerciseLabelPill({super.key, required this.label});

  final ExerciseLabel label;

  static Color colorOf(ExerciseLabel label) => switch (label) {
    ExerciseLabel.newWord => AppColors.purple,
    ExerciseLabel.mistake || ExerciseLabel.pastMistake => AppColors.red,
    ExerciseLabel.weak => AppColors.orange,
    ExerciseLabel.hard => AppColors.gold,
  };

  static IconData iconOf(ExerciseLabel label) => switch (label) {
    ExerciseLabel.newWord => Icons.auto_awesome,
    ExerciseLabel.mistake || ExerciseLabel.pastMistake => Icons.refresh,
    ExerciseLabel.weak => Icons.fitness_center,
    ExerciseLabel.hard => Icons.bolt,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(label);
    return Semantics(
      label: label.text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTokens.tint(color, context),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconOf(label), size: 14, color: color),
            const SizedBox(width: 4),
            // Ink, not the accent, so the text keeps its contrast in both
            // themes whatever the palette's hues become.
            Text(
              label.text,
              style: AppTextStyles.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTokens.ink(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
