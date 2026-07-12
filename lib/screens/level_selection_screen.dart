import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/level_models.dart';
import '../services/api_service.dart';
import '../services/progress_service.dart';
import '../utils/topic_visuals.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  List<Level> levels = [];
  bool isLoading = true;

  static const List<Color> _sectionColors = [
    Color(0xFF2C97DD), // Blue
    Color(0xFF58CC02), // Green
    Color(0xFFCE82FF), // Purple
    Color(0xFFFF9600), // Orange
  ];

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
      final remoteLevels = await ApiService().getLearningLevels();
      if (remoteLevels != null && remoteLevels.isNotEmpty) {
        setState(() {
          levels = Level.fromApiLevels(remoteLevels);
          isLoading = false;
        });
        return;
      }

      final String jsonString = await rootBundle.loadString(
        'assets/quiz_data/levels.json',
      );
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final List<Level> loadedLevels =
          (jsonData['levels'] as List)
              .map((level) => Level.fromJson(level))
              .toList();

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
            content: Text('Error loading topics: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _sectionColor(int index) {
    return _sectionColors[index % _sectionColors.length];
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _titleColor => _isDark ? Colors.white : const Color(0xFF2C3E50);

  Color get _subtitleColor =>
      _isDark ? Colors.grey.shade400 : Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressService>(
      builder: (context, progressService, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Learn Tibetan',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _titleColor,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: _titleColor,
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
                  ? _buildEmptyState()
                  : _buildTopicSections(progressService),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Could not load topics',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: _subtitleColor,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _subtitleColor,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
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

  Widget _buildTopicSections(ProgressService progressService) {
    final totalTopics = levels.fold<int>(
      0,
      (sum, level) => sum + level.sublevels.length,
    );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          'Pick a topic',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _titleColor,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        const SizedBox(height: 4),
        Text(
          '$totalTopics topics to explore. Each lesson is a short quiz.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _subtitleColor,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < levels.length; i++) ...[
          if (levels[i].sublevels.isNotEmpty) ...[
            _buildSectionHeader(levels[i], _sectionColor(i)),
            const SizedBox(height: 12),
            _buildTopicGrid(levels[i], _sectionColor(i), progressService),
            const SizedBox(height: 24),
          ],
        ],
      ],
    );
  }

  Widget _buildSectionHeader(Level level, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            level.title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _titleColor,
            ).copyWith(fontFamilyFallback: const ['Jomolhari']),
          ),
        ),
        Text(
          '${level.sublevels.length} topics',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: _subtitleColor,
            fontWeight: FontWeight.w500,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
      ],
    );
  }

  Widget _buildTopicGrid(
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
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: level.sublevels.length,
      itemBuilder: (context, index) {
        final sublevel = level.sublevels[index];
        final progressKey = sublevel.path.split('/').last.split('.').first;
        final progress = progressService.categoryProgress[progressKey] ?? 0.0;
        return _buildTopicCard(sublevel, color, progress);
      },
    );
  }

  Widget _buildTopicCard(Sublevel sublevel, Color color, double progress) {
    final isLocked = sublevel.isLocked;
    final isCompleted = progress > 0.7;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isLocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Earn ${sublevel.requiredXp} XP to unlock ${sublevel.name}.',
                ),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizScreen(topicFilePath: sublevel.path),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isCompleted
                      ? Colors.green.withOpacity(0.5)
                      : _isDark
                      ? Colors.white12
                      : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(_isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      topicEmoji(sublevel.name),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const Spacer(),
                  if (isLocked)
                    Icon(Icons.lock, size: 18, color: Colors.grey.shade500)
                  else if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.green,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                sublevel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isLocked ? Colors.grey : _titleColor,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              const SizedBox(height: 2),
              Text(
                sublevel.wordCount > 0
                    ? '${sublevel.wordCount} words'
                    : 'Lesson',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _subtitleColor,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              if (progress > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor:
                        _isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? Colors.green : color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
