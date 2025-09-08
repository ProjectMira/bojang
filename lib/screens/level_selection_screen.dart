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

  // Responsive design helpers
  double _getResponsiveValue(BuildContext context, {
    required double small,
    required double medium, 
    required double large,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 380) return small;      // iPhone SE, small screens
    if (screenWidth < 414) return medium;    // iPhone 8, standard screens  
    return large;                            // iPhone Plus, Pro Max, large screens
  }

  int _getResponsiveColumns(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 380) return 2;        // iPhone SE: 2 columns for more space
    if (screenWidth < 500) return 3;        // Standard phones: 3 columns
    return 4;                               // Large screens/tablets: 4 columns
  }

  double _getResponsivePadding(BuildContext context) {
    return _getResponsiveValue(context, small: 16.0, medium: 20.0, large: 24.0);
  }

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
      
      final List<Level> loadedLevels = (jsonData['levels'] as List)
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
            content: Text('Error loading levels: $e'),
            duration: const Duration(seconds: 5),
          ),
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
    final responsivePadding = _getResponsivePadding(context);
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: responsivePadding, vertical: responsivePadding),
      child: Column(
        children: levels.asMap().entries.map((entry) {
          final levelIndex = entry.key;
          final level = entry.value;
          final color = _getLevelColor(level.level);

          return Column(
            children: [
              if (levelIndex > 0)
                Container(
                  height: _getResponsiveValue(context, small: 32, medium: 40, large: 48),
                  width: 4,
                  color: Colors.grey[300],
                ),
              ScaleTransition(
                scale: _scaleAnimation,
                child: _buildLevelNode(level, color),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLevelNode(Level level, Color color) {
    final containerPadding = _getResponsiveValue(context, small: 12.0, medium: 16.0, large: 20.0);
    final marginBottom = _getResponsiveValue(context, small: 12.0, medium: 16.0, large: 20.0);
    
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(containerPadding),
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
                      padding: EdgeInsets.all(_getResponsiveValue(context, small: 10, medium: 12, large: 16)),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${level.level}',
                        style: GoogleFonts.kalam(
                          fontSize: _getResponsiveValue(context, small: 20, medium: 24, large: 28),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: _getResponsiveValue(context, small: 12, medium: 16, large: 20)),
                    Expanded(
                      child: Text(
                        level.title,
                        style: GoogleFonts.kalam(
                          fontSize: _getResponsiveValue(context, small: 20, medium: 24, large: 28),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _getResponsiveValue(context, small: 12, medium: 16, large: 20)),
                level.sublevels.isEmpty
                    ? Center(
                        child: Text(
                          '🔒 Coming Soon!',
                          style: GoogleFonts.kalam(
                            fontSize: _getResponsiveValue(context, small: 16, medium: 20, large: 24),
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
    final columns = _getResponsiveColumns(context);
    final spacing = _getResponsiveValue(context, small: 6, medium: 8, large: 12);
    final aspectRatio = _getResponsiveValue(context, small: 1.0, medium: 0.95, large: 0.9);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_fill,
                      color: color,
                      size: _getResponsiveValue(context, small: 24, medium: 28, large: 32),
                    ),
                    SizedBox(height: _getResponsiveValue(context, small: 4, medium: 6, large: 8)),
                    Text(
                      sublevel.level.toString(),
                      style: GoogleFonts.kalam(
                        fontSize: _getResponsiveValue(context, small: 14, medium: 16, large: 18),
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    SizedBox(height: _getResponsiveValue(context, small: 2, medium: 2, large: 4)),
                    Flexible(
                      child: Text(
                        sublevel.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.kalam(
                          fontSize: _getResponsiveValue(context, small: 10, medium: 12, large: 14),
                          color: color,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            fontSize: _getResponsiveValue(context, small: 20, medium: 24, large: 28),
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
          : levels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: _getResponsiveValue(context, small: 48, medium: 64, large: 80),
                        color: Colors.grey,
                      ),
                      SizedBox(height: _getResponsiveValue(context, small: 12, medium: 16, large: 20)),
                      Text(
                        'No levels found',
                        style: GoogleFonts.kalam(
                          fontSize: _getResponsiveValue(context, small: 16, medium: 20, large: 24),
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
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
                )
              : _buildLevelPath(),
    );
  }
}
