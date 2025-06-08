import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const TibetanLearningApp());
}

class TibetanLearningApp extends StatelessWidget {
  const TibetanLearningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tibetan Learning App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
