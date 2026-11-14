import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_config.dart';
import '../services/google_auth_service.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/yak_mascot.dart';
import 'main_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService});

  final GoogleAuthService? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Which provider's sheet is open, so the other button can be disabled and
/// only the pressed one shows a spinner.
enum _SignInMethod { apple, google, email }

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  _SignInMethod? _loadingMethod;

  bool get _isLoading => _loadingMethod != null;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late final GoogleAuthService _googleAuthService =
      widget.authService ?? GoogleAuthService();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _obscurePassword = true;
  String? _emailError;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSubmit() async {
    setState(() => _emailError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loadingMethod = _SignInMethod.email);

    try {
      final user =
          _isCreatingAccount
              ? await _googleAuthService.createAccountWithEmail(
                name: _nameController.text,
                email: _emailController.text,
                password: _passwordController.text,
              )
              : await _googleAuthService.signInWithEmail(
                email: _emailController.text,
                password: _passwordController.text,
              );
      if (user != null && mounted) {
        _showSnackBar('Welcome ${user.displayName}!', isSuccess: true);
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToMainScreen();
      } else if (mounted) {
        setState(() => _emailError = _emailErrorMessage(null));
      }
    } catch (e) {
      if (mounted) setState(() => _emailError = _emailErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingMethod = null);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(
        () => _emailError = 'Enter your email above, then tap "Forgot password?"',
      );
      return;
    }
    try {
      await _googleAuthService.sendPasswordResetEmail(email);
      if (mounted) {
        setState(() => _emailError = null);
        _showSnackBar(
          'If an account exists for $email, a reset link is on its way.',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _emailError = _emailErrorMessage(e));
    }
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  String _emailErrorMessage(Object? error) {
    final code =
        error is firebase_auth.FirebaseAuthException ? error.code : null;
    switch (code) {
      case 'invalid-email':
        return "That email address doesn't look right.";
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Sign in instead.';
      case 'weak-password':
        return 'Choose a password with at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
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
      // null means the user dismissed Apple's sheet: no message.
    } catch (e) {
      if (mounted) _showSignInIssueDialog('Apple', detail: _errorDetail(e));
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
      if (mounted) _showSignInIssueDialog('Google', detail: _errorDetail(e));
    } finally {
      if (mounted) setState(() => _loadingMethod = null);
    }
  }

  // A quotable description of a failure. Shown in the dialog so a screenshot
  // from a tester — or from App Review — carries the actual error instead of
  // only "didn't complete". Apple's nested error is the useful part and sits
  // at the end, so keep enough room for it; the dialog scrolls.
  String _errorDetail(Object error) {
    final text = error.toString().replaceAll('\n', ' ').trim();
    return text.length > 600 ? '${text.substring(0, 597)}…' : text;
  }

  void _showSignInIssueDialog(String provider, {String? detail}) {
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please check your connection and try again in a moment. '
                    'You can also continue without an account — every learning '
                    'feature works on this device, and you can sign in anytime '
                    'from the Profile tab.',
                    style: GoogleFonts.poppins().copyWith(
                      fontFamilyFallback: const ['Jomolhari'],
                    ),
                  ),
                  if (detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      detail,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                    ),
                  ],
                ],
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
                  const SizedBox(height: 24),
                  _buildLogo(),
                  const SizedBox(height: 32),
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
        const YakMascot(mood: YakMood.waving, size: 150),
        const SizedBox(height: 12),
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
              'Sign in to keep your XP, streaks, and league progress across devices.',
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
            if (AppConfig.emailSignInEnabled) _buildEmailForm(),
            if (AppConfig.emailSignInEnabled &&
                (AppConfig.appleSignInEnabled ||
                    AppConfig.googleSignInEnabled))
              _buildDivider(),
            if (AppConfig.appleSignInEnabled) ...[
              AppleSignInButton(
                onPressed: _isLoading ? null : _handleAppleSignIn,
                isLoading: _loadingMethod == _SignInMethod.apple,
              ),
              const SizedBox(height: 12),
            ],
            if (AppConfig.googleSignInEnabled)
              GoogleSignInButton(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                isLoading: _loadingMethod == _SignInMethod.google,
              ),
          ],
        ),
      ),
    );
  }

  TextStyle get _fieldTextStyle =>
      GoogleFonts.poppins().copyWith(fontFamilyFallback: const ['Jomolhari']);

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildEmailForm() {
    final isEmailLoading = _loadingMethod == _SignInMethod.email;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isCreatingAccount) ...[
              TextFormField(
                key: const Key('nameField'),
                controller: _nameController,
                enabled: !_isLoading,
                style: _fieldTextStyle,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _fieldDecoration('Your name', Icons.person_outline),
                validator:
                    (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Please enter your name'
                            : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const Key('emailField'),
              controller: _emailController,
              enabled: !_isLoading,
              style: _fieldTextStyle,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: _fieldDecoration('Email', Icons.mail_outline),
              validator:
                  (value) =>
                      _looksLikeEmail(value ?? '')
                          ? null
                          : 'Please enter a valid email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('passwordField'),
              controller: _passwordController,
              enabled: !_isLoading,
              style: _fieldTextStyle,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: [
                _isCreatingAccount
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              onFieldSubmitted: (_) => _isLoading ? null : _handleEmailSubmit(),
              decoration: _fieldDecoration(
                'Password',
                Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed:
                      () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                final password = value ?? '';
                if (password.isEmpty) return 'Please enter your password';
                if (_isCreatingAccount && password.length < 6) {
                  return 'Use at least 6 characters';
                }
                return null;
              },
            ),
            if (!_isCreatingAccount)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              )
            else
              const SizedBox(height: 12),
            if (_emailError != null) ...[
              Text(
                _emailError!,
                key: const Key('emailError'),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.error,
                ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 52,
              child: ElevatedButton(
                key: const Key('emailSubmitButton'),
                onPressed: _isLoading ? null : _handleEmailSubmit,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    isEmailLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                        : Text(
                          _isCreatingAccount ? 'Create account' : 'Sign in',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ).copyWith(fontFamilyFallback: const ['Jomolhari']),
                        ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('toggleAuthModeButton'),
              onPressed:
                  _isLoading
                      ? null
                      : () => setState(() {
                        _isCreatingAccount = !_isCreatingAccount;
                        _emailError = null;
                      }),
              child: Text(
                _isCreatingAccount
                    ? 'Already have an account? Sign in'
                    : 'New to Bojang? Create an account',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final color = Colors.grey.shade400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: color)),
          ),
          Expanded(child: Divider(color: color)),
        ],
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
