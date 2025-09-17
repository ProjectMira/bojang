import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  late GoogleSignIn _googleSignIn;
  final ApiService _apiService = ApiService();
  
  User? _currentUser;
  bool _isInitialized = false;

  // Getters
  User? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  // Initialize Google Sign-In
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
      );

      // Load cached user data if available
      await _loadCachedUser();
      _isInitialized = true;
      print('Google Sign-In initialized successfully');
    } catch (e) {
      print('Google Sign-In initialization error: $e');
      // Still mark as initialized to prevent repeated attempts
      _isInitialized = true;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      if (!_isInitialized) await initialize();

      // Check if Google Sign-In is properly configured
      if (!await _isGoogleSignInConfigured()) {
        print('Google Sign-In not properly configured - using demo mode');
        return _createDemoUser();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        print('Google sign-in cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create user object from Google data
      final user = User(
        id: googleUser.id,
        email: googleUser.email,
        username: _generateUsername(googleUser.email),
        displayName: googleUser.displayName ?? 'Google User',
        profileImageUrl: googleUser.photoUrl,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        googleId: googleUser.id,
        authProvider: AuthProvider.google,
      );

      // Try to send to backend API for registration/login
      try {
        final result = await _apiService.googleAuth(
          googleId: googleUser.id,
          email: googleUser.email,
          displayName: googleUser.displayName ?? 'Google User',
          profileImageUrl: googleUser.photoUrl,
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        if (result != null) {
          // Update user with backend data if available
          final backendUser = User.fromJson(result['user']);
          _currentUser = backendUser;
          await _cacheUser(backendUser);
          return backendUser;
        }
      } catch (apiError) {
        print('Backend API error during Google auth: $apiError');
        // Continue with offline mode
      }

      // Use Google data if backend is not available or failed
      _currentUser = user;
      await _cacheUser(user);
      return user;
    } catch (error) {
      print('Google Sign-In error: $error');
      // Provide more specific error information
      if (error.toString().contains('sign_in_canceled')) {
        print('User cancelled Google sign-in');
      } else if (error.toString().contains('network_error')) {
        print('Network error during Google sign-in');
      } else if (error.toString().contains('sign_in_failed')) {
        print('Google sign-in failed - check configuration');
      }
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (_isInitialized) {
        await _googleSignIn.signOut();
      }
      await _apiService.logout();
      _currentUser = null;
      await _clearCachedUser();
    } catch (error) {
      print('Sign out error: $error');
    }
  }

  // Silent sign in (for app startup)
  Future<User?> signInSilently() async {
    try {
      if (!_isInitialized) await initialize();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        return _currentUser; // Return cached user if available
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Verify with backend if possible
      final result = await _apiService.googleAuth(
        googleId: googleUser.id,
        email: googleUser.email,
        displayName: googleUser.displayName ?? 'Google User',
        profileImageUrl: googleUser.photoUrl,
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      if (result != null) {
        final user = User.fromJson(result['user']);
        _currentUser = user;
        await _cacheUser(user);
        return user;
      }

      return _currentUser;
    } catch (error) {
      print('Silent sign-in error: $error');
      return _currentUser;
    }
  }

  // Check if user is currently signed in to Google
  Future<bool> isSignedInToGoogle() async {
    if (!_isInitialized) await initialize();
    return await _googleSignIn.isSignedIn();
  }

  // Get current Google account
  GoogleSignInAccount? get currentGoogleAccount => _googleSignIn.currentUser;

  // Private helper methods
  String _generateUsername(String email) {
    return email.split('@')[0].replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  Future<void> _cacheUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(user.toJson()));
  }

  Future<void> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUserJson = prefs.getString('cached_user');
    if (cachedUserJson != null) {
      try {
        final userMap = jsonDecode(cachedUserJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userMap);
      } catch (e) {
        print('Error loading cached user: $e');
      }
    }
  }

  Future<void> _clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
  }

  // Check if Google Sign-In is properly configured
  Future<bool> _isGoogleSignInConfigured() async {
    try {
      // Try to access Google Sign-In configuration
      await _googleSignIn.isSignedIn();
      return true;
    } catch (e) {
      // If this throws an error, configuration is likely missing
      print('Google Sign-In configuration error: $e');
      return false;
    }
  }

  // Create a demo user for testing when Google Sign-In is not configured
  User _createDemoUser() {
    final demoUser = User(
      id: 'demo_user_${DateTime.now().millisecondsSinceEpoch}',
      email: 'demo@bojang.app',
      username: 'demouser',
      displayName: 'Demo User',
      profileImageUrl: null,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      googleId: null,
      authProvider: AuthProvider.google,
    );
    
    _currentUser = demoUser;
    _cacheUser(demoUser);
    return demoUser;
  }
}
