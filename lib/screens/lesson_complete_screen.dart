import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../services/analytics.dart';
import '../services/location_service.dart';
import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import '../widgets/app_text_style.dart';
import '../widgets/yak_mascot.dart';
import 'quiz_screen.dart';
import 'streak_celebration_screen.dart';
import '../widgets/content_width.dart';

/// Full-screen celebration shown after finishing a lesson. Replaces the old
/// blocking completion AlertDialog.
class LessonCompleteScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int xpEarned;
  final double accuracy;
  final int streak;
  final String topicFilePath;
  final String? title;

  const LessonCompleteScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.xpEarned,
    required this.accuracy,
    required this.streak,
    required this.topicFilePath,
    this.title,
  });

  @override
  State<LessonCompleteScreen> createState() => _LessonCompleteScreenState();
}

class _LessonCompleteScreenState extends State<LessonCompleteScreen> {
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;

  bool get _isSuccess => widget.accuracy >= 70;

  @override
  void initState() {
    super.initState();
    _confettiLeft = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    _confettiRight = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    if (_isSuccess) {
      _confettiLeft.play();
      _confettiRight.play();
    }
    // The first lesson of the day extended the streak: celebrate it once
    // this screen has had a moment. After the first finished lesson, ask
    // once to share approximate location, after any streak celebration.
    Future<void>.delayed(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;
      await StreakCelebrationScreen.maybeShow(context);
      if (mounted) LocationService.instance.maybePromptAfterLesson(context);
    });
  }

  @override
  void dispose() {
    _confettiLeft.dispose();
    _confettiRight.dispose();
    super.dispose();
  }

  void _trackAction(String action) {
    Analytics.track('lesson_complete_action', {
      'action': action,
      'topic': widget.title,
      'topic_path': widget.topicFilePath,
      'score': widget.score,
      'total': widget.totalQuestions,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTokens.isDark(context);
    final resultColor = _isSuccess ? AppColors.gold : AppColors.primary;
    final line = YakLines.lessonComplete(accuracy: widget.accuracy);
    const confettiColors = [
      AppColors.primary,
      AppColors.gold,
      AppColors.green,
      AppColors.purple,
    ];

    return Scaffold(
      backgroundColor: AppTokens.background(context),
      body: ContentWidth(
        maxWidth: ContentWidth.reading,
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: ConfettiWidget(
                  confettiController: _confettiLeft,
                  blastDirection: math.pi / 3,
                  emissionFrequency: 0.06,
                  numberOfParticles: 10,
                  maxBlastForce: 18,
                  minBlastForce: 6,
                  gravity: 0.3,
                  shouldLoop: false,
                  colors: confettiColors,
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: ConfettiWidget(
                  confettiController: _confettiRight,
                  blastDirection: math.pi - math.pi / 3,
                  emissionFrequency: 0.06,
                  numberOfParticles: 10,
                  maxBlastForce: 18,
                  minBlastForce: 6,
                  gravity: 0.3,
                  shouldLoop: false,
                  colors: confettiColors,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  resultColor.withOpacity(isDark ? 0.16 : 0.08),
                                  resultColor.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                          // The yak is the celebration: it jumps for a pass
                          // and cheers the learner on otherwise.
                          YakMascot(
                            mood: line.mood,
                            size: 230,
                            semanticLabel:
                                _isSuccess
                                    ? '${YakLines.name} the yak is cheering'
                                    : '${YakLines.name} the yak is cheering you on',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        line.title,
                        style: AppTextStyles.display(context),
                        textAlign: TextAlign.center,
                      ),
                      if (line.body != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          line.body!,
                          style: AppTextStyles.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTokens.ink(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'You scored ${widget.score} of ${widget.totalQuestions} '
                        '(${widget.accuracy.toStringAsFixed(0)}%)',
                        style: AppTextStyles.poppins(
                          fontSize: 14,
                          color: AppTokens.inkSoft(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildStatChip(
                            context,
                            '⚡',
                            '+${widget.xpEarned} XP',
                            AppColors.gold,
                          ),
                          _buildStatChip(
                            context,
                            '🎯',
                            '${widget.accuracy.toStringAsFixed(0)}%',
                            AppColors.primary,
                          ),
                          _buildStatChip(
                            context,
                            '🔥',
                            '${widget.streak} streak',
                            AppColors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            _trackAction('continue');
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                            ),
                          ),
                          child: Text(
                            'Continue',
                            style: AppTextStyles.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _trackAction('practice_again');
                          Navigator.of(context).pushReplacement(
                            screenRoute(
                              'quiz',
                              (context) => QuizScreen(
                                topicFilePath: widget.topicFilePath,
                                title: widget.title,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Practice again',
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.inkSoft(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String emoji,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.tint(color, context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
