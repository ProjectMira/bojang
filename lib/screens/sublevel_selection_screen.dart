import 'package:flutter/material.dart';
import '../data/quiz_data.dart';
import 'quiz_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class SublevelSelectionScreen extends StatelessWidget {
  final int level;
  const SublevelSelectionScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final topics = QuizData.getTopicsForLevel(level);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Level $level',
          style: GoogleFonts.kalam(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: topics.isEmpty
          ? Center(
              child: Text(
                'No sublevels available yet.',
                style: GoogleFonts.kalam(fontSize: 20, color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: topics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final topic = topics[index];
                final displayName = _getDisplayName(topic['key']!);
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    foregroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 70),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: GoogleFonts.kalam(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizScreen(topicFilePath: topic['file']!),
                      ),
                    );
                  },
                  child: Text(displayName),
                );
              },
            ),
    );
  }

  String _getDisplayName(String key) {
    switch (key) {
      case 'alphabet':
        return 'Alphabet';
      case 'vowels':
        return 'Vowels';
      case 'word_meaning':
        return 'Word Meaning';
      case 'body_parts':
        return 'Body Parts';
      case 'fruits_vegetables':
        return 'Fruits and Vegetables';
      default:
        return key.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
    }
  }
} 