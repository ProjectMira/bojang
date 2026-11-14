import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import 'app_text_style.dart';
import 'yak_mascot.dart';

/// Non-blocking bottom banner shown after answering a quiz question.
/// Replaces the old AlertDialog so gameplay feels continuous; the caller
/// still owns the 2-second auto-advance timing via [visible].
///
/// A wrong answer ends the question, so [correctAnswerText] is shown with it —
/// the learner does not get another attempt to discover the answer.
class AnswerFeedbackBanner extends StatelessWidget {
  final bool visible;
  final bool isCorrect;
  final String? correctAnswerText;

  /// Right answers in a row, this one included. Drives the yak's "3 in a
  /// row!" moments.
  final int combo;

  /// Picks which line the yak says; pass the question index so the line is
  /// stable for one question and varies across the lesson.
  final int seed;

  const AnswerFeedbackBanner({
    super.key,
    required this.visible,
    required this.isCorrect,
    this.correctAnswerText,
    this.combo = 1,
    this.seed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.green : AppColors.red;
    final line =
        isCorrect
            ? YakLines.correct(seed: seed, combo: combo)
            : YakLines.incorrect(seed: seed);
    // A solid fill (accent blended into the opaque surface color) rather
    // than a see-through tint, since this sits on top of scrollable quiz
    // content and needs to stay fully legible.
    final fill = Color.alphaBlend(
      color.withOpacity(0.16),
      AppTokens.surface(context),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // The yak reacts; the badge keeps the right/wrong signal
                // readable without relying on its expression or on color.
                SizedBox(
                  width: 68,
                  height: 64,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      YakMascot(
                        // Hidden banners keep a resting yak so the reaction
                        // plays as the banner slides in.
                        mood: visible ? line.mood : YakMood.happy,
                        size: 64,
                        showBody: false,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: fill, width: 2),
                          ),
                          child: Icon(
                            isCorrect
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        line.title,
                        style: AppTextStyles.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (isCorrect && line.body != null)
                        Text(
                          line.body!,
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            color: AppTokens.inkSoft(context),
                          ),
                        ),
                      if (!isCorrect &&
                          correctAnswerText != null &&
                          correctAnswerText!.isNotEmpty)
                        Text(
                          'Answer: $correctAnswerText',
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            color: AppTokens.inkSoft(context),
                          ),
                        ),
                    ],
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
