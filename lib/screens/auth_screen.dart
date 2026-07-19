import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_config.dart';
import '../services/google_auth_service.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/google_sign_in_button.dart';
import 'main_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService});

  final GoogleAuthService? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _SignInMethod { apple, google }

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  _SignInMethod? _loadingMethod;

  bool get _isLoading => _loadingMethod != null;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late final GoogleAuthService _googleAuthService =
      widget.authService ?? GoogleAuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _googleAuthService.initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _loadingMethod = _SignInMethod.apple);

    try {
      final user = await _googleAuthService.signInWithApple();
      if (user != null && mounted) {
        _showSnackBar('Welcome ${user.displayName}!', isSuccess: true);
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Brief delay to show success
        _navigateToMainScreen();
      }
      // null means the user dismissed the Apple sign-in sheet: no message.
    } catch (e) {
      if (mounted) _showSignInIssueDialog('Apple');
    } finally {
      if (mounted) setState(() => _loadingMethod = null);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loadingMethod = _SignInMethod.google);

    try {
      final user = await _googleAuthService.signInWithGoogle();
      if (user != null && mounted) {
        _showSnackBar('Welcome ${user.displayName}!', isSuccess: true);
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Brief delay to show success
        _navigateToMainScreen();
      }
      // null means the user cancelled Google sign-in: no message.
    } catch (e) {
      if (mounted) _showSignInIssueDialog('Google');
    } finally {
      if (mounted) setState(() => _loadingMethod = null);
    }
  }

  void _showSignInIssueDialog(String provider) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "$provider sign-in didn't complete",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
            ),
            content: Text(
              'Please check your connection and try again in a moment. '
              'You can also continue without an account — every learning '
              'feature works on this device, and you can sign in anytime '
              'from the Profile tab.',
              style: GoogleFonts.poppins().copyWith(
                fontFamilyFallback: const ['Jomolhari'],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _navigateToMainScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/main'),
        builder: (context) => const MainNavigationScreen(),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : null,
        duration:
            isSuccess
                ? const Duration(milliseconds: 1500)
                : const Duration(milliseconds: 4000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  _buildLogo(),
                  const SizedBox(height: 48),
                  _buildAuthCard(),
                  const SizedBox(height: 32),
                  _buildSkipButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'Bojang',
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF2C3E50),
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
        const SizedBox(height: 8),
        Text(
          'Practice Tibetan every day',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save your progress',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2C3E50),
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to sync XP, streaks, and league progress across devices.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
              ).copyWith(fontFamilyFallback: const ['Jomolhari']),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (AppConfig.appleSignInEnabled) ...[
              AppleSignInButton(
                onPressed: _isLoading ? null : _handleAppleSignIn,
                isLoading: _loadingMethod == _SignInMethod.apple,
              ),
              const SizedBox(height: 12),
            ],
            GoogleSignInButton(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              isLoading: _loadingMethod == _SignInMethod.google,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: _navigateToMainScreen,
      child: Text(
        'Continue without account',
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: Colors.grey.shade500,
          decoration: TextDecoration.underline,
        ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      ),
    );
  }
}
