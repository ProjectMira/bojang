import 'package:flutter/material.dart';
import 'quiz_screen.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Level'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLevelButton(context, 1),
            const SizedBox(height: 20),
            _buildLevelButton(context, 2),
            const SizedBox(height: 20),
            _buildLevelButton(context, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, int level) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 20),
        textStyle: const TextStyle(fontSize: 20),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(level: level),
          ),
        );
      },
      child: Text('Level $level'),
    );
  }
} 