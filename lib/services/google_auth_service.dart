import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'app_config.dart';
import 'api_service.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  GoogleSignIn? _googleSignIn;
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
      if (kIsWeb) {
        await _loadCachedUser();
        _isInitialized = true;
        print(
          'Google Sign-In skipped on web until a web client ID is configured',
        );
        return;
      }

      _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

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
      if (_googleSignIn == null) {
        print('Google Sign-In is not configured for this platform');
        return null;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        print('Google sign-in cancelled by user');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final backendToken = await _firebaseIdTokenFromGoogle(googleAuth);

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
          idToken: backendToken ?? googleAuth.idToken,
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

  // Sign in with Apple (native flow through Firebase Auth; iOS/macOS only)
  Future<User?> signInWithApple() async {
    if (!AppConfig.firebaseEnabled) {
      print('Apple Sign-In requires Firebase, which is disabled in this build');
      return null;
    }

    try {
      final appleProvider =
          firebase_auth.AppleAuthProvider()
            ..addScope('email')
            ..addScope('name');
      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithProvider(appleProvider);
      final firebaseUser = credential.user;
      if (firebaseUser == null) return null;

      final idToken = await firebaseUser.getIdToken();
      // Apple only shares the name on the first authorization, and the email
      // may be a private relay address when the user hides their email.
      final email = firebaseUser.email ?? '';
      final displayName =
          (firebaseUser.displayName?.trim().isNotEmpty ?? false)
              ? firebaseUser.displayName!.trim()
              : (email.contains('@') ? email.split('@').first : 'Learner');

      final user = User(
        id: firebaseUser.uid,
        email: email,
        username:
            email.contains('@') ? _generateUsername(email) : firebaseUser.uid,
        displayName: displayName,
        profileImageUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        authProvider: AuthProvider.apple,
      );

      if (email.isNotEmpty && idToken != null) {
        try {
          final result = await _apiService.appleAuth(
            uid: firebaseUser.uid,
            email: email,
            displayName: displayName,
            profileImageUrl: firebaseUser.photoURL,
            idToken: idToken,
          );

          if (result != null) {
            final backendUser = User.fromJson(result['user']);
            _currentUser = backendUser;
            await _cacheUser(backendUser);
            return backendUser;
          }
        } catch (apiError) {
          print('Backend API error during Apple auth: $apiError');
          // Continue with offline mode
        }
      }

      // Use Apple data if backend is not available or failed
      _currentUser = user;
      await _cacheUser(user);
      return user;
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'canceled' ||
          error.code == 'user-cancelled' ||
          error.code == 'web-context-cancelled') {
        print('Apple sign-in cancelled by user');
        return null;
      }
      print('Apple Sign-In error: ${error.code} ${error.message}');
      return null;
    } catch (error) {
      print('Apple Sign-In error: $error');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (_isInitialized) {
        await _googleSignIn?.signOut();
      }
      if (AppConfig.firebaseEnabled) {
        try {
          await firebase_auth.FirebaseAuth.instance.signOut();
        } catch (_) {}
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
      if (_googleSignIn == null) return _currentUser;

      final GoogleSignInAccount? googleUser =
          await _googleSignIn!.signInSilently();
      if (googleUser == null) {
        return _currentUser; // Return cached user if available
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final backendToken = await _firebaseIdTokenFromGoogle(googleAuth);

      // Verify with backend if possible
      final result = await _apiService.googleAuth(
        googleId: googleUser.id,
        email: googleUser.email,
        displayName: googleUser.displayName ?? 'Google User',
        profileImageUrl: googleUser.photoUrl,
        idToken: backendToken ?? googleAuth.idToken,
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
    return await _googleSignIn?.isSignedIn() ?? false;
  }

  // Get current Google account
  GoogleSignInAccount? get currentGoogleAccount => _googleSignIn?.currentUser;

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

  Future<String?> _firebaseIdTokenFromGoogle(
    GoogleSignInAuthentication googleAuth,
  ) async {
    if (!AppConfig.firebaseEnabled) return null;

    try {
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(credential);
      return result.user?.getIdToken();
    } catch (e) {
      print('Firebase token exchange skipped: $e');
      return null;
    }
  }
}
