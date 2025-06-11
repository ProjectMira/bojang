import 'package:flutter/material.dart';
import 'sublevel_selection_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLevelButton(context, 1, 'Beginner', Colors.green),
              const SizedBox(height: 32),
              _buildLevelButton(context, 2, 'Intermediate', Colors.blue),
              const SizedBox(height: 32),
              _buildLevelButton(context, 3, 'Advanced', Colors.purple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, int level, String title, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        minimumSize: const Size(double.infinity, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: GoogleFonts.kalam(fontSize: 24, fontWeight: FontWeight.bold),
        elevation: 4,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SublevelSelectionScreen(level: level),
          ),
        );
      },
      child: Text(title),
    );
  }
} 