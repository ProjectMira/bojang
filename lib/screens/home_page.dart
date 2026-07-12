import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/progress_service.dart';
import '../services/theme_service.dart';
import '../services/api_service.dart';
import '../widgets/cultural_tip_card.dart';
import 'level_selection_screen.dart';
import 'settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshServerProgress(),
    );
  }

  Future<void> _refreshServerProgress() async {
    if (!ApiService().isAuthenticated || !mounted) return;
    final stats = await ApiService().getUserProgress();
    if (stats != null && mounted) {
      await Provider.of<ProgressService>(
        context,
        listen: false,
      ).updateFromServer(stats);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProgressService, ThemeService>(
      builder: (context, progressService, themeService, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with settings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back',
                              style: GoogleFonts.poppins( 
                                fontSize: 16,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                            ),
                            Text(
                              'Ready for Tibetan?',
                              style: GoogleFonts.poppins( 
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF2C3E50),
                              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.settings,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                            size: 28,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Primary CTA: start a lesson
                    _buildStartLessonHero(progressService),

                    const SizedBox(height: 24),

                    // Quick Stats (streak lives here, compact)
                    _buildQuickStats(progressService),

                    const SizedBox(height: 32),

                    // Cultural Tip of the Day
                    Text(
                      'Cultural Tip',
                      style: GoogleFonts.poppins( 
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF2C3E50),
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),

                    const SizedBox(height: 16),

                    _buildCulturalTip(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartLessonHero(ProgressService progressService) {
    final hasProgress = progressService.totalQuizzesTaken > 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C97DD), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C97DD).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LevelSelectionScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('📚', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasProgress ? 'Continue Learning' : 'Start a Lesson',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Practice vocabulary, phrases, and verbs',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                        ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(ProgressService progressService) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            progressService.xp > 0 ? 'XP' : 'Accuracy',
            progressService.xp > 0
                ? '${progressService.xp}'
                : '${progressService.accuracy.toStringAsFixed(0)}%',
            progressService.xp > 0 ? Icons.bolt : Icons.track_changes,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Streak',
            '${progressService.currentStreak}',
            Icons.local_fire_department,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            progressService.completedLevelsCount > 0 ? 'Lessons' : 'Level',
            progressService.completedLevelsCount > 0
                ? '${progressService.completedLevelsCount}'
                : '${progressService.currentLevel}',
            Icons.trending_up,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins( 
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF2C3E50),
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          Text(
            title,
            style: GoogleFonts.poppins( 
              fontSize: 12,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
        ],
      ),
    );
  }

  Widget _buildCulturalTip() {
    final tipData = CulturalTipsData.getRandomTip();
    return CulturalTipCard(
      title: tipData['title'],
      tip: tipData['tip'],
      tibetanText: tipData['tibetan'],
      icon: tipData['icon'],
      color: tipData['color'],
    );
  }

}
