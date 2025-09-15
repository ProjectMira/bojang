import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/google_auth_service.dart';
import '../services/api_service.dart';
import 'main_navigation_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final ApiService _apiService = ApiService();

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

    // Navigate to appropriate screen after animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAuthenticationStatus();
      }
    });
  }

  Future<void> _checkAuthenticationStatus() async {
    await _googleAuthService.initialize();
    await _apiService.initialize();

    // Try to sign in silently with Google
    final user = await _googleAuthService.signInSilently();
    
    // Small delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Widget nextScreen;
      
      if (user != null || _apiService.isAuthenticated) {
        // User is authenticated, go to main screen
        nextScreen = const MainNavigationScreen();
      } else {
        // User is not authenticated, show auth screen
        nextScreen = const AuthScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
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
    }
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
              // Transparent logo head
              Image.asset(
                'logos/Bojang/without_background.jpg',
                width: 280,
                height: 280,
                fit: BoxFit.contain,
              ),
              
              const SizedBox(height: 30),
              
              // App Name - "Bojang" in big and bold
              Text(
                'BOJANG',
                style: GoogleFonts.comfortaa(
                  fontSize: 48,
                  fontWeight: FontWeight.w700, // Feather Bold equivalent
                  color: Colors.white,
                  letterSpacing: 3.0,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Tagline
              Text(
                'Tibetan Learning App',
                style: GoogleFonts.comfortaa(
                  fontSize: 20,
                  fontWeight: FontWeight.w400, // Feather regular equivalent
                  color: Colors.white,
                  letterSpacing: 1.0,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              
              // Additional tagline
              const SizedBox(height: 12),
              Text(
                'བོད་ཡིག་སློབ་པ།',
                style: GoogleFonts.comfortaa(
                  fontSize: 18,
                  fontWeight: FontWeight.w400, // Feather regular equivalent
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 