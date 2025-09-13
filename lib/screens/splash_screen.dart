import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'level_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Navigate to LevelSelectionScreen after animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const LevelSelectionScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: Tween<double>(
                    begin: 0.0,
                    end: 1.0,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C97DD), // New blue background
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo - clean without container
              Image.asset(
                'logos/Bojang/logo.jpg',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
              ),
              
              const SizedBox(height: 30),
              
              // App Name - "Bojang" in big and bold
              Text(
                'BOJANG',
                style: GoogleFonts.fredoka(  // Balloon-style font alternative
                  fontSize: 42,
                  fontWeight: FontWeight.w800, // Extra bold
                  color: const Color(0xFFAE6B45), // New brown color
                  letterSpacing: 2.0,
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Tagline
              Text(
                'Learn Tibetan Language',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w800, // Extra bold
                  color: const Color(0xFFAE6B45), // New brown color
                  letterSpacing: 0.5,
                ),
              ),
              
              // Additional tagline
              const SizedBox(height: 8),
              Text(
                'བོད་ཡིག་སློབ་པ།',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w800, // Extra bold
                  color: const Color(0xFFAE6B45), // New brown color
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 