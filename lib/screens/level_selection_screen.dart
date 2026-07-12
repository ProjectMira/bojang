import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/level_models.dart';
import '../services/levels_repository.dart';
import '../services/progress_service.dart';
import '../theme/app_tokens.dart';
import '../utils/topic_visuals.dart';
import '../widgets/app_text_style.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

const List<IconData> _kSectionIcons = [
  Icons.menu_book_rounded,
  Icons.translate_rounded,
  Icons.record_voice_over_rounded,
  Icons.extension_rounded,
];

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  List<Level> levels = [];
  bool isLoading = true;

  int _getColumns(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 600) return 3;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    try {
      final loadedLevels = await LevelsRepository.loadLevels();
      setState(() {
        levels = loadedLevels;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text('Error loading topics: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _sectionColor(int index) =>
      kSectionColors[index % kSectionColors.length];

  IconData _sectionIcon(int index) =>
      _kSectionIcons[index % _kSectionIcons.length];

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressService>(
      builder: (context, progressService, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Learn Tibetan',
              style: AppTextStyles.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTokens.ink(context),
              ),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: AppTokens.ink(context),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body:
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : levels.isEmpty
                  ? _buildEmptyState(context)
                  : _buildTopicSections(context, progressService),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Could not load topics',
            style: AppTextStyles.poppins(
              fontSize: 20,
              color: AppTokens.inkSoft(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            style: AppTextStyles.poppins(
              fontSize: 14,
              color: AppTokens.inkSoft(context),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _loadLevels();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicSections(
    BuildContext context,
    ProgressService progressService,
  ) {
    final totalTopics = levels.fold<int>(
      0,
      (sum, level) => sum + level.sublevels.length,
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Pick a topic', style: AppTextStyles.display(context)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: AppTextStyles.poppins(
              fontSize: 14,
              color: AppTokens.inkSoft(context),
            ),
            children: [
              TextSpan(
                text: '$totalTopics topics',
                style: AppTextStyles.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(text: ' · each lesson is a short quiz'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < levels.length; i++) ...[
          if (levels[i].sublevels.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              levels[i],
              _sectionColor(i),
              _sectionIcon(i),
            ),
            const SizedBox(height: 14),
            _buildTopicGrid(
              context,
              levels[i],
              _sectionColor(i),
              progressService,
            ),
            const SizedBox(height: 32),
          ],
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    Level level,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(level.title, style: AppTextStyles.title(context))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTokens.tint(color, context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${level.sublevels.length}',
            style: AppTextStyles.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicGrid(
    BuildContext context,
    Level level,
    Color color,
    ProgressService progressService,
  ) {
    final columns = _getColumns(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.18,
      ),
      itemCount: level.sublevels.length,
      itemBuilder: (context, index) {
        final sublevel = level.sublevels[index];
        final progressKey = sublevel.path.split('/').last.split('.').first;
        final progress = progressService.categoryProgress[progressKey] ?? 0.0;
        return _TopicCard(sublevel: sublevel, color: color, progress: progress);
      },
    );
  }
}

class _TopicCard extends StatefulWidget {
  final Sublevel sublevel;
  final Color color;
  final double progress;

  const _TopicCard({
    required this.sublevel,
    required this.color,
    required this.progress,
  });

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.sublevel.isLocked;
    final isCompleted = widget.progress > 0.7;
    final isDark = AppTokens.isDark(context);

    final tintOpacity = isLocked ? 0.06 : (isDark ? 0.22 : 0.10);

    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: Material(
        color: AppTokens.tint(widget.color, context, opacity: tintOpacity),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          splashColor: widget.color.withOpacity(0.12),
          highlightColor: widget.color.withOpacity(0.08),
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Text(
                    'Earn ${widget.sublevel.requiredXp} XP to unlock ${widget.sublevel.name}.',
                  ),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        QuizScreen(topicFilePath: widget.sublevel.path),
              ),
            );
          },
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTokens.surface(context),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                topicEmoji(widget.sublevel.name),
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.sublevel.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color:
                                    isLocked
                                        ? AppTokens.inkSoft(context)
                                        : AppTokens.ink(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.sublevel.wordCount > 0
                                  ? '${widget.sublevel.wordCount} words'
                                  : 'Lesson',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: widget.progress.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor:
                              isDark
                                  ? Colors.black.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.6),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? AppColors.green : widget.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (isLocked)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTokens.inkSoft(context).withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 12,
                        color: Colors.white,
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
