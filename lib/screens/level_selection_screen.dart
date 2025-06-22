import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/level_models.dart';
import 'quiz_screen.dart';
import 'notification_settings_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> with SingleTickerProviderStateMixin {
  List<Level> levels = [];
  bool isLoading = true;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _loadLevels();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLevels() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quiz_data/levels.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        levels = (jsonData['levels'] as List).map((level) => Level.fromJson(level)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading levels: $e')),
        );
      }
    }
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF58CC02); // Green
      case 2:
        return const Color(0xFF1CB0F6); // Blue
      case 3:
        return const Color(0xFFCE82FF); // Purple
      default:
        return Colors.grey;
    }
  }

  Widget _buildLevelPath() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      itemCount: levels.length,
      itemBuilder: (context, levelIndex) {
        final level = levels[levelIndex];
        final color = _getLevelColor(level.level);

        return Column(
          children: [
            if (levelIndex > 0)
              Container(
                height: 40,
                width: 4,
                color: Colors.grey[300],
              ),
            ScaleTransition(
              scale: _scaleAnimation,
              child: _buildLevelNode(level, color),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLevelNode(Level level, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${level.level}',
                        style: GoogleFonts.kalam(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        level.title,
                        style: GoogleFonts.kalam(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                level.sublevels.isEmpty
                    ? Center(
                        child: Text(
                          '🔒 Coming Soon!',
                          style: GoogleFonts.kalam(
                            fontSize: 20,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : _buildSublevels(level, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSublevels(Level level, Color color) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: level.sublevels.length,
      itemBuilder: (context, index) {
        final sublevel = level.sublevels[index];
        final isLocked = false;

        return Hero(
          tag: 'sublevel_${sublevel.level}_${sublevel.name}',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(topicFilePath: sublevel.path),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_fill,
                      color: color,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sublevel.level.toString(),
                      style: GoogleFonts.kalam(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sublevel.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.kalam(
                        fontSize: 14,
                        color: color,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          'Learn Tibetan',
          style: GoogleFonts.kalam(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLevelPath(),
    );
  }
}
