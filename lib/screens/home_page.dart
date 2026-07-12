import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/level_models.dart';
import '../services/api_service.dart';
import '../services/levels_repository.dart';
import '../services/progress_service.dart';
import '../theme/app_tokens.dart';
import '../utils/topic_visuals.dart';
import '../widgets/app_text_style.dart';
import '../widgets/cultural_tip_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shortcut_card.dart';
import '../widgets/stat_strip.dart';
import 'level_selection_screen.dart';
import 'memory_match_game.dart';
import 'quiz_screen.dart';

class HomePage extends StatefulWidget {
  /// Switches the bottom nav to the Streak tab. Provided by
  /// [MainNavigationScreen]; left null when HomePage is used standalone.
  final VoidCallback? onSeeStreak;

  const HomePage({super.key, this.onSeeStreak});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<Level> _levels = [];
  bool _levelsLoading = true;

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
    _loadShortcutTopics();
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

  Future<void> _loadShortcutTopics() async {
    try {
      final levels = await LevelsRepository.loadLevels();
      if (!mounted) return;
      setState(() {
        _levels = levels;
        _levelsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _levelsLoading = false);
    }
  }

  List<Sublevel> get _shortcutTopics {
    final unlocked = <Sublevel>[];
    for (final level in _levels) {
      unlocked.addAll(level.sublevels.where((s) => !s.isLocked));
      if (unlocked.length >= 3) break;
    }
    return unlocked.take(3).toList();
  }

  Future<void> _shareApp() async {
    final uri = Uri.parse('https://www.bojang.in');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressService>(
      builder: (context, progressService, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),

                    const SizedBox(height: AppSpacing.xl),

                    _buildStatsStrip(context, progressService),

                    const SizedBox(height: AppSpacing.section),

                    SectionHeader(
                      title: 'Categories',
                      actionLabel: 'See all',
                      onAction:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const LevelSelectionScreen(),
                            ),
                          ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    _buildShortcutGrid(context),

                    const SizedBox(height: AppSpacing.section),

                    _buildStartLessonHero(context, progressService),

                    const SizedBox(height: AppSpacing.section),

                    const SectionHeader(title: 'Cultural Tip'),

                    const SizedBox(height: AppSpacing.md),

                    _buildCulturalTip(),

                    const SizedBox(height: AppSpacing.section),

                    _buildShareButton(context),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back', style: AppTextStyles.caption(context)),
        const SizedBox(height: 2),
        Text('Ready for Tibetan?', style: AppTextStyles.display(context)),
      ],
    );
  }

  Widget _buildStatsStrip(
    BuildContext context,
    ProgressService progressService,
  ) {
    final hasXp = progressService.xp > 0;
    final hasLessons = progressService.completedLevelsCount > 0;

    return StatStrip(
      onTap: widget.onSeeStreak,
      items: [
        StatStripItem(
          icon: Icons.local_fire_department,
          value: '${progressService.currentStreak}',
          label: 'Streak',
          color: AppColors.orange,
        ),
        StatStripItem(
          icon: Icons.bolt,
          value:
              hasXp
                  ? '${progressService.xp}'
                  : '${progressService.accuracy.toStringAsFixed(0)}%',
          label: hasXp ? 'XP' : 'Accuracy',
          color: AppColors.gold,
        ),
        StatStripItem(
          icon: Icons.auto_stories_rounded,
          value:
              hasLessons
                  ? '${progressService.completedLevelsCount}'
                  : '${progressService.currentLevel}',
          label: hasLessons ? 'Lessons' : 'Level',
          color: AppColors.green,
        ),
      ],
    );
  }

  Widget _buildShortcutGrid(BuildContext context) {
    const topicColors = [AppColors.primary, AppColors.green, AppColors.orange];
    final topics = _shortcutTopics;

    final cards = <Widget>[];
    if (topics.isEmpty) {
      final placeholderCount = _levelsLoading ? 3 : 0;
      for (var i = 0; i < placeholderCount; i++) {
        cards.add(_buildShortcutSkeleton(context));
      }
    } else {
      for (var i = 0; i < topics.length; i++) {
        final sublevel = topics[i];
        cards.add(
          ShortcutCard(
            emoji: topicEmoji(sublevel.name),
            title: sublevel.name,
            subtitle:
                sublevel.wordCount > 0
                    ? '${sublevel.wordCount} words'
                    : 'Lesson',
            color: topicColors[i % topicColors.length],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => QuizScreen(topicFilePath: sublevel.path),
                ),
              );
            },
          ),
        );
      }
    }

    cards.add(
      ShortcutCard(
        emoji: '🧠',
        title: 'Memory Match',
        subtitle: 'Game',
        color: AppColors.purple,
        leading: _buildMemoryCardFan(context),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MemoryMatchGame()),
          );
        },
      ),
    );

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: cards,
    );
  }

  Widget _buildMemoryCardFan(BuildContext context) {
    Widget miniCard(double angle, Color color, String? label) {
      return Transform.rotate(
        angle: angle,
        child: Container(
          width: 30,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              label != null
                  ? Text(label, style: const TextStyle(fontSize: 16))
                  : null,
        ),
      );
    }

    return SizedBox(
      width: 78,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: miniCard(-0.20, AppTokens.surface(context), null),
          ),
          Positioned(
            right: 0,
            child: miniCard(0.20, AppTokens.surface(context), null),
          ),
          miniCard(0, AppColors.purple, '🧠'),
        ],
      ),
    );
  }

  Widget _buildShortcutSkeleton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.tint(AppTokens.inkSoft(context), context),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    );
  }

  Widget _buildStartLessonHero(
    BuildContext context,
    ProgressService progressService,
  ) {
    final hasProgress = progressService.totalQuizzesTaken > 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppTokens.heroShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -28,
              child: Text(
                'ཀ',
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.08),
                  fontFamilyFallback: const ['Jomolhari'],
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.hero),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LevelSelectionScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasProgress
                                  ? 'Continue Learning'
                                  : 'Start a Lesson',
                              style: AppTextStyles.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Practice vocabulary, phrases, and verbs',
                              style: AppTextStyles.poppins(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
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
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildShareButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _shareApp,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        icon: const Icon(Icons.favorite_rounded, size: 20),
        label: Text(
          'Share Bojang — bojang.in',
          style: AppTextStyles.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
