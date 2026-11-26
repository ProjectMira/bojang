import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/learning_path_repository.dart';
import '../services/onboarding_service.dart';
import '../services/reading_help.dart';
import 'onboarding_screen.dart';
import '../services/google_auth_service.dart';
import '../services/api_service.dart';
import '../utils/yak_lines.dart';
import '../widgets/yak_mascot.dart';
import 'main_navigation_screen.dart';
import '../services/analytics.dart';
import '../theme/app_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  /// The splash never stays longer than this (including the fade out), even
  /// on a first open where creating the anonymous account waits on the
  /// network. Sign-in that is still running carries on in the background.
  static const maxSplash = Duration(milliseconds: 2700);

  /// Long enough to see the yak, short enough not to feel like a wait.
  static const minSplash = Duration(milliseconds: 1200);

  static const fadeOut = Duration(milliseconds: 300);

  late AnimationController _controller;
  late Animation<double> _animation;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final ApiService _apiService = ApiService();
  final Stopwatch _shown = Stopwatch()..start();
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // What the install held before this launch, for "existing users never
    // see onboarding". Taken first, before sign-in writes anything.
    _installSnapshot = _snapshotInstall();

    // Sign-in starts at once, alongside the animation, instead of after it.
    _start();
  }

  late final Future<({Set<String> keys, bool hadAccount})> _installSnapshot;
  bool _showOnboarding = false;

  static Future<({Set<String> keys, bool hadAccount})> _snapshotInstall() async {
    var keys = <String>{};
    var hadAccount = false;
    try {
      keys = (await SharedPreferences.getInstance()).getKeys();
    } catch (_) {}
    try {
      hadAccount =
          Firebase.apps.isNotEmpty &&
          firebase_auth.FirebaseAuth.instance.currentUser != null;
    } catch (_) {}
    return (keys: keys, hadAccount: hadAccount);
  }

  Future<void> _decideOnboarding() async {
    try {
      final snapshot = await _installSnapshot;
      final service = OnboardingService.instance;
      final previous = await service.status();
      _showOnboarding = await service.shouldShow(
        storedKeys: snapshot.keys,
        hadAccount: snapshot.hadAccount,
      );
      if (_showOnboarding && previous != null) {
        Analytics.track('onboarding_restarted', {
          'last_step': await service.lastStep(),
        });
      }
    } catch (e) {
      debugPrint('Onboarding check failed: $e');
      _showOnboarding = false;
    }
  }

  Future<void> _start() async {
    final startup = _checkAuthenticationStatus();
    unawaited(ReadingHelp.instance.load());
    await _decideOnboarding();
    // Leave as soon as sign-in is done (but not before minSplash), and never
    // later than maxSplash.
    await Future.any([
      Future.wait([startup, Future<void>.delayed(minSplash)]),
      Future<void>.delayed(maxSplash),
    ]);
    Analytics.track('splash_finished', {
      'ms': _shown.elapsedMilliseconds,
      'startup_done': _startupDone,
    });
    _leave();
  }

  bool _startupDone = false;

  Future<void> _checkAuthenticationStatus() async {
    try {
      await _googleAuthService.initialize();
      await _apiService.initialize();

      // Try to sign in silently with Google
      final user = await _googleAuthService.signInSilently();

      // No sign-in wall: learners who have not created an account get an
      // anonymous one so their progress still syncs. If that cannot happen
      // (offline), progress stays on the device and the app works the same.
      var anonymous = false;
      if (user == null) {
        anonymous = await _googleAuthService.ensureAnonymousSession().timeout(
          const Duration(seconds: 6),
          onTimeout: () => false,
        );
      }
      Analytics.track('app_launched', {
        'restored_session': user != null,
        'auth_provider': user?.authProvider.name,
        'is_anonymous': user == null ? anonymous : null,
      });
      // Home opens on the path: start fetching it while the splash fades.
      LearningPathRepository.prefetch();
      // Onboarding answers given offline (or before the account existed).
      unawaited(OnboardingService.instance.syncPending());
    } catch (e) {
      // Startup must never trap the learner on the splash.
      debugPrint('Startup sign-in failed: $e');
    } finally {
      _startupDone = true;
    }
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    // New installs get a short onboarding that ends in their first lesson;
    // everyone else starts learning right away. Signing in is offered from
    // the Profile tab and the "save your progress" ask.
    final Widget nextScreen =
        _showOnboarding ? const OnboardingScreen() : const MainNavigationScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: RouteSettings(name: _showOnboarding ? 'onboarding' : 'main'),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: fadeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The yak waves hello — the same character learners meet on
              // every screen after this one.
              const YakMascot(
                mood: YakMood.waving,
                size: 280,
                semanticLabel: '${YakLines.name} the yak waving hello',
              ),

              const SizedBox(height: 24),
              
              // App Name - "Bojang" in big and bold
               Text(
                'BOJANG',
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w800, // Extra bold for feather-like effect
                  color: const Color(0xFF8B4513), // Saddle brown color
                  letterSpacing: 3.0,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              
              const SizedBox(height: 20),
              
              // Tagline
              Text(
                'Tibetan Learning App',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700, // Bold for consistency
                  color: const Color(0xFF8B4513), // Saddle brown color
                  letterSpacing: 1.0,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
              
              // Additional tagline
              const SizedBox(height: 12),
              Text(
                'བོད་ཡིག་སློབ་པ།',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600, // Semi-bold for consistency
                  color: const Color(0xFF8B4513).withOpacity(0.9), // Brown with opacity
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 