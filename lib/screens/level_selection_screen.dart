import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/level_models.dart';
import 'quiz_screen.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});

  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> {
  List<Level> levels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quiz_data/levels.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      setState(() {
        levels = (jsonData['levels'] as List)
            .map((level) => Level.fromJson(level))
            .toList();
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
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLevelCard(Level level) {
    final color = _getLevelColor(level.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(
          level.title,
          style: GoogleFonts.kalam(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        backgroundColor: color.withOpacity(0.1),
        collapsedBackgroundColor: color.withOpacity(0.1),
        children: [
          if (level.sublevels.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No sublevels available yet',
                style: GoogleFonts.kalam(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: level.sublevels.length,
              itemBuilder: (context, index) {
                final sublevel = level.sublevels[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    title: Text(
                      sublevel.name,
                      style: GoogleFonts.kalam(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Level ${sublevel.level}',
                      style: GoogleFonts.kalam(),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            topicFilePath: sublevel.path,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bojang',
          style: GoogleFonts.kalam(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: levels.map((level) => _buildLevelCard(level)).toList(),
                ),
              ),
            ),
    );
  }
}