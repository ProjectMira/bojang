import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import 'quiz_screen.dart';

/// Full-screen celebration shown after finishing a lesson. Replaces the old
/// blocking completion AlertDialog.
class LessonCompleteScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int xpEarned;
  final double accuracy;
  final int streak;
  final String topicFilePath;

  const LessonCompleteScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.xpEarned,
    required this.accuracy,
    required this.streak,
    required this.topicFilePath,
  });

  @override
  State<LessonCompleteScreen> createState() => _LessonCompleteScreenState();
}

class _LessonCompleteScreenState extends State<LessonCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;
  late final ConfettiController _confettiLeft;
  late final ConfettiController _confettiRight;

  bool get _isSuccess => widget.accuracy >= 70;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    final target =
        widget.totalQuestions > 0 ? widget.score / widget.totalQuestions : 0.0;
    _ringAnimation = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic),
    );
    _confettiLeft = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    _confettiRight = ConfettiController(
      duration: const Duration(milliseconds: 2500),
    );
    _ringController.forward();
    if (_isSuccess) {
      _confettiLeft.play();
      _confettiRight.play();
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _confettiLeft.dispose();
    _confettiRight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTokens.isDark(context);
    final resultColor = _isSuccess ? AppColors.gold : AppColors.primary;
    const confettiColors = [
      AppColors.primary,
      AppColors.gold,
      AppColors.green,
      AppColors.purple,
    ];

    return Scaffold(
      backgroundColor: AppTokens.background(context),
      body: SafeArea(
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
                        _buildScoreRing(context, resultColor),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _isSuccess ? 'ལེགས་སོ། Excellent!' : 'Keep practicing!',
                      style: AppTextStyles.display(context),
                      textAlign: TextAlign.center,
                    ),
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
                        onPressed: () => Navigator.of(context).pop(),
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
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder:
                                (context) => QuizScreen(
                                  topicFilePath: widget.topicFilePath,
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
    );
  }

  Widget _buildScoreRing(BuildContext context, Color ringColor) {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: _ringAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTokens.tint(ringColor, context),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: _ringAnimation.value,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isSuccess ? '🏆' : '⭐',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.score}/${widget.totalQuestions}',
                    style: AppTextStyles.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTokens.ink(context),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
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
