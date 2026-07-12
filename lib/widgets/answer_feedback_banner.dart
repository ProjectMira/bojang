import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';

/// Non-blocking bottom banner shown after answering a quiz question.
/// Replaces the old AlertDialog so gameplay feels continuous; the caller
/// still owns the 2-second auto-advance timing via [visible].
class AnswerFeedbackBanner extends StatelessWidget {
  final bool visible;
  final bool isCorrect;

  const AnswerFeedbackBanner({
    super.key,
    required this.visible,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.green : AppColors.red;
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
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.close_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isCorrect
                        ? 'ལེགས་སོ། Amazing!'
                        : 'སེམས་ཤུགས་མ་ཆག — try again!',
                    style: AppTextStyles.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
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
