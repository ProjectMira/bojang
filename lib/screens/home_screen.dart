import 'package:flutter/material.dart';
import 'level_selection_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bojang'),
        centerTitle: true,
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            textStyle: const TextStyle(fontSize: 24),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LevelSelectionScreen(),
              ),
            );
          },
          child: const Text('Learn Now'),
        ),
      ),
    );
  }
} 