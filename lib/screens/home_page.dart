import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/learning_path.dart';
import '../models/level_models.dart';
import '../services/analytics.dart';
import '../services/api_service.dart';
import '../services/feature_flags.dart';
import '../services/learning_path_repository.dart';
import '../services/levels_repository.dart';
import '../services/progress_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../utils/topic_visuals.dart';
import '../utils/yak_lines.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/offline_lessons_banner.dart';
import '../widgets/app_text_style.dart';
import '../widgets/cultural_tip_card.dart';
import '../widgets/earn_back_card.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/learning_path_view.dart';
import '../widgets/scenery/biome.dart';
import '../widgets/section_header.dart';
import '../widgets/shortcut_card.dart';
import '../widgets/stat_strip.dart';
import '../widgets/yak_says.dart';
import 'level_selection_screen.dart';
import 'path_navigation.dart';
import 'memory_match_game.dart';
import 'lesson_intro_screen.dart';
import '../widgets/content_width.dart';

/// Home: the status bar (streak, daily goal, voice) and the learning path
/// (GET /learn/path). With the `learning_path_enabled` flag off, or before
/// any path has ever loaded, it shows the classic topic shortcuts instead.
class HomePage extends StatefulWidget {
  /// Opens the streak screen from the stats strip of the classic Home.
  /// Left null to open the streak sheet.
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

  LearningPath? _path;
  // True until the first fetch has answered; meanwhile Home shows the
  // path's outline rather than the classic topic page.
  bool _pathLoading = true;
  bool _pathEnabled = LearningPathRepository.enabled;
  final GlobalKey _activeKey = GlobalKey();
  bool _scrolledToActive = false;

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
    _loadPath();
    FeatureFlags.instance.changes.addListener(_onFlagsChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshServerProgress(),
    );
  }

  Future<void> _refreshServerProgress() async {
    if (!ApiService().isAuthenticated || !mounted) return;
    // Send any day that couldn't reach the server last time first, so the
    // stats below already include it.
    await Provider.of<ProgressService>(
      context,
      listen: false,
    ).flushPendingActivity();
    if (!mounted) return;
    final stats = await ApiService().getUserProgress();
    if (stats != null && mounted) {
      await Provider.of<ProgressService>(
        context,
        listen: false,
      ).updateFromServer(stats);
    }
  }

  void _onFlagsChanged() {
    final enabled = LearningPathRepository.enabled;
    if (enabled == _pathEnabled || !mounted) return;
    setState(() => _pathEnabled = enabled);
    if (enabled) _loadPath();
  }

  Future<void> _loadPath() async {
    if (!_pathEnabled) return;
    final watch = Stopwatch()..start();
    final hadPath = _path != null;
    // The copy on the device paints at once; the server's replaces it.
    if (_path == null) {
      final cached = await LearningPathRepository.cached();
      if (cached != null && mounted && _path == null) {
        Analytics.track('path_cache_shown', {'ms': watch.elapsedMilliseconds});
        setState(() => _path = cached);
        _scrollToActiveOnce();
      }
    }
    final path = await LearningPathRepository.load();
    if (!mounted) return;
    setState(() {
      _path = path ?? _path;
      _pathLoading = false;
    });
    if (path != null) {
      Analytics.track('path_loaded', {
        'ms': watch.elapsedMilliseconds,
        'refresh': hadPath,
        'units': path.units.length,
        'active_node_id': path.activeNodeId,
        'daily_sessions': path.daily?.sessions,
        'daily_goal': path.daily?.goal,
      });
      _scrollToActiveOnce();
    }
  }

  void _scrollToActiveOnce() {
    if (_scrolledToActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _activeKey.currentContext;
      if (target == null || !mounted) return;
      _scrolledToActive = true;
      Scrollable.ensureVisible(
        target,
        alignment: 0.35,
        duration: Motion.read(context).scale(const Duration(milliseconds: 450)),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openNode(PathNode node) async {
    final path = _path;
    await openPathNode(
      context,
      node,
      source: 'home_path',
      unit: path?.unitOf(node),
    );
    if (!mounted) return;
    await _loadPath();
    await _refreshServerProgress();
  }

  void _showLocked(PathNode node) {
    final path = _path;
    if (path == null) return;
    showLockedNode(
      context,
      path,
      node,
      source: 'home_path',
      onGoToActive: () {
        final active = path.activeNode;
        if (active != null) _openNode(active);
      },
    );
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
    Analytics.track('home_shortcut_tapped', {'shortcut': 'share'});
    Analytics.track('app_shared', {'channel': 'website_link'});
    final uri = Uri.parse('https://www.bojang.in');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    FeatureFlags.instance.changes.removeListener(_onFlagsChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressService>(
      builder: (context, progressService, child) {
        final path = _pathEnabled ? _path : null;
        if (_pathEnabled && path == null && _pathLoading) {
          return const _PathLoadingHome();
        }
        return Scaffold(
          // With the path, the page is the mist the valleys sit in.
          backgroundColor:
              path != null
                  ? BiomePalette.mistFor(AppTokens.isDark(context))
                  : Theme.of(context).scaffoldBackgroundColor,
          body: ContentWidth(
            // The scenery runs edge to edge; the path keeps its own column.
            maxWidth: path != null ? double.infinity : ContentWidth.standard,
            // The page runs under the floating tab bar; the scroll view's
            // bottom padding carries the bar's height instead.
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadPath();
                    await _refreshServerProgress();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      path != null ? 0 : AppSpacing.gutter,
                      AppSpacing.lg,
                      path != null ? 0 : AppSpacing.gutter,
                      AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                    ),
                    child:
                        path != null
                            ? _buildPathHome(context, progressService, path)
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HomeTopBar(daily: _path?.daily),

                                const SizedBox(height: AppSpacing.lg),

                                _buildHeader(context, progressService),

                                const SizedBox(height: AppSpacing.xl),

                                const AnnouncementBanner(),
                                const OfflineLessonsBanner(),

                                _buildStatsStrip(context, progressService),

                                _buildEarnBack(context, progressService),

                                const SizedBox(height: AppSpacing.section),

                                SectionHeader(
                                  title: 'Categories',
                                  actionLabel: 'See all',
                                  onAction: () {
                                    Analytics.track('home_shortcut_tapped', {
                                      'shortcut': 'see_all_categories',
                                    });
                                    Navigator.push(
                                      context,
                                      screenRoute(
                                        'level_selection',
                                        (context) =>
                                            const LevelSelectionScreen(),
                                      ),
                                    );
                                  },
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
            ),
          ),
        );
      },
    );
  }

  /// Home with the learning path: status bar, notices, then the path.
  Widget _buildPathHome(
    BuildContext context,
    ProgressService progressService,
    LearningPath path,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContentWidth(
          maxWidth: LearningPathView.columnWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeTopBar(daily: path.daily),
                const SizedBox(height: AppSpacing.lg),
                const AnnouncementBanner(),
                _buildEarnBack(context, progressService),
              ],
            ),
          ),
        ),
        LearningPathView(
          path: path,
          activeKey: _activeKey,
          onOpen: _openNode,
          onLocked: _showLocked,
        ),
        Center(
          child: TextButton.icon(
            onPressed: () {
              Analytics.track('home_shortcut_tapped', {
                'shortcut': 'all_topics',
              });
              Navigator.push(
                context,
                screenRoute(
                  'level_selection',
                  (context) => const LevelSelectionScreen(initialTopics: true),
                ),
              );
            },
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Browse all topics'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// The yak greets the learner and says the one thing that matters right
  /// now: start, keep the streak, or well done for today.
  Widget _buildHeader(BuildContext context, ProgressService progress) {
    final now = DateTime.now();
    final practicedToday = progress.playDates.any(
      (d) => d.year == now.year && d.month == now.month && d.day == now.day,
    );
    return YakSays.line(
      YakLines.home(
        now: now,
        streak: progress.currentStreak,
        practicedToday: practicedToday,
        isNewLearner: progress.totalQuizzesTaken == 0,
      ),
      yakSize: 112,
    );
  }

  Widget _buildStatsStrip(
    BuildContext context,
    ProgressService progressService,
  ) {
    final hasXp = progressService.xp > 0;
    final hasLessons = progressService.completedLevelsCount > 0;

    return StatStrip(
      onTap: () {
        Analytics.track('home_shortcut_tapped', {'shortcut': 'streak'});
        final open = widget.onSeeStreak;
        open != null ? open() : showStreakSheet(context, source: 'home_stats');
      },
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

  /// While a broken streak can still be earned back: days left and lessons
  /// done, one tap from a lesson.
  Widget _buildEarnBack(BuildContext context, ProgressService progress) {
    final now = DateTime.now();
    final earnBack = progress.earnBackOn(now);
    if (earnBack == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: EarnBackCard(
        earnBack: earnBack,
        today: now,
        compact: true,
        onStart: () {
          Analytics.track('earn_back_card_tapped', {
            'source': 'home',
            'streak': earnBack.streak,
            'sessions_done': earnBack.sessionsDone,
            'days_left': earnBack.daysLeft(now),
          });
          Navigator.push(
            context,
            screenRoute(
              'level_selection',
              (context) => const LevelSelectionScreen(),
            ),
          );
        },
      ),
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
                sublevel.hasLesson
                    ? 'Basics lesson'
                    : sublevel.wordCount > 0
                    ? '${sublevel.wordCount} words'
                    : 'Lesson',
            color: topicColors[i % topicColors.length],
            onTap: () {
              Analytics.track('home_shortcut_tapped', {
                'shortcut': 'topic',
                'topic': sublevel.name,
                'topic_path': sublevel.path,
                'position': i,
              });
              openTopic(context, sublevel, source: 'home_shortcut');
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
          Analytics.track('home_shortcut_tapped', {'shortcut': 'memory_match'});
          Navigator.push(
            context,
            screenRoute('memory_match', (context) => const MemoryMatchGame()),
          );
        },
      ),
    );

    // Phone: a 2x2 block. iPad: the same four cards in one row.
    final wide = Breakpoints.isTablet(context);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: wide ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: wide ? 1.2 : 1.45,
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
                  Analytics.track('home_shortcut_tapped', {'shortcut': 'hero'});
                  Navigator.push(
                    context,
                    screenRoute(
                      'level_selection',
                      (context) => const LevelSelectionScreen(),
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

/// Home while the first path is on its way: the same mist and top bar, with
/// the outline of the trail, so the page never flashes the old topic list.
class _PathLoadingHome extends StatelessWidget {
  const _PathLoadingHome();

  @override
  Widget build(BuildContext context) {
    final dark = AppTokens.isDark(context);
    final ghost = (dark ? Colors.white : Colors.black).withValues(alpha: 0.07);
    return Scaffold(
      backgroundColor: BiomePalette.mistFor(dark),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          maxWidth: LearningPathView.columnWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              0,
            ),
            // Clipped, not scrolled: the outline is only a placeholder.
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                const HomeTopBar(daily: null),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  label: 'Loading your path',
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: ghost,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(math.sin(i * math.pi / 3) * 70, 0),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: ghost,
                            shape: BoxShape.circle,
                          ),
                        ),
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
