import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_tokens.dart';
import 'memory_match_game.dart';
import 'speed_quiz_screen.dart';

class ExtraGamesScreen extends StatelessWidget {
  const ExtraGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Games',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTokens.ink(context),
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.ink(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'More Ways to Learn',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2C3E50),
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            const SizedBox(height: 8),
            Text(
              'Short games that use the same vocabulary as your lessons — perfect for a quick practice break.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            const SizedBox(height: 24),
            _buildGameCard(
              context,
              title: 'Memory Match',
              description:
                  'Flip cards to match Tibetan words with their meanings. Pick any topic you\'re learning.',
              emoji: '🧠',
              color: Colors.purple,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MemoryMatchGame(),
                    ),
                  ),
            ),
            const SizedBox(height: 16),
            _buildGameCard(
              context,
              title: 'Speed Quiz',
              description:
                  'Answer as many questions as you can in 60 seconds. Beat your best score!',
              emoji: '⚡',
              color: Colors.orange,
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SpeedQuizScreen(),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    required String description,
    required String emoji,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2C3E50),
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color:
                            isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
