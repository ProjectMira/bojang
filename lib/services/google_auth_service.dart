import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'app_config.dart';
import 'api_service.dart';
import 'apple_sign_in.dart';
import 'firebase_account_link.dart';
import 'package:firebase_core/firebase_core.dart';

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
      if (error.toString().contains('sign_in_canceled')) {
        print('User cancelled Google sign-in');
        return null;
      }
      print('Google Sign-In error: $error');
      rethrow;
    }
  }

  // Sign in with Apple. The native sheet and the Firebase credential exchange
  // live in [AppleSignIn]; this method turns the resulting Firebase user into
  // an app account, exactly as the Google path does.
  Future<User?> signInWithApple() async {
    if (!AppConfig.firebaseEnabled) {
      print('Apple Sign-In requires Firebase, which is disabled in this build');
      return null;
    }

    final firebaseUser = await const AppleSignIn().signIn(
      surfaceRefusals: AppConfig.appleSignInDiagnosticsEnabled,
    );
    if (firebaseUser == null) return null;

    return _completeFirebaseSignIn(firebaseUser, AuthProvider.apple);
  }

  // Sign in to an existing email/password account. Firebase errors
  // (wrong-password, user-not-found, ...) propagate as
  // FirebaseAuthException so the screen can explain them.
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!AppConfig.firebaseEnabled) {
      throw StateError('Email sign-in requires Firebase');
    }
    final credential = await firebase_auth.FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email.trim(), password: password);
    final firebaseUser = credential.user;
    if (firebaseUser == null) return null;
    return _completeFirebaseSignIn(firebaseUser, AuthProvider.email);
  }

  // Create an email/password account and sign it in.
  Future<User?> createAccountWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!AppConfig.firebaseEnabled) {
      throw StateError('Email sign-up requires Firebase');
    }
    final auth = firebase_auth.FirebaseAuth.instance;
    final current = auth.currentUser;
    // Upgrade the anonymous first-launch account in place so the progress
    // already synced under its uid stays with the learner.
    final credential =
        (current != null && current.isAnonymous)
            ? await current.linkWithCredential(
              firebase_auth.EmailAuthProvider.credential(
                email: email.trim(),
                password: password,
              ),
            )
            : await auth.createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
    final createdUser = credential.user;
    if (createdUser == null) return null;
    var firebaseUser = createdUser;

    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      try {
        await firebaseUser.updateDisplayName(trimmedName);
        await firebaseUser.reload();
        firebaseUser =
            firebase_auth.FirebaseAuth.instance.currentUser ?? firebaseUser;
      } catch (e) {
        print('Email sign-up: could not store display name: $e');
      }
    }
    final user = await _completeFirebaseSignIn(
      firebaseUser,
      AuthProvider.email,
      fallbackName: trimmedName,
    );
    // An upgraded anonymous account already exists on the backend without a
    // name, and /auth/sync leaves existing profiles alone.
    if (user != null && trimmedName.isNotEmpty) {
      try {
        await _apiService.updateUserProfile(displayName: trimmedName);
      } catch (e) {
        print('Email sign-up: could not sync display name: $e');
      }
    }
    return user;
  }

  /// Gives a learner who has not signed in an anonymous Firebase account, so
  /// their progress syncs to the backend without any sign-up. Returns true when
  /// an anonymous session is active. Never throws: offline, the app simply
  /// keeps progress on the device.
  Future<bool> ensureAnonymousSession() async {
    if (!AppConfig.anonymousSessionsEnabled || _currentUser != null) {
      return false;
    }
    try {
      if (Firebase.apps.isEmpty) return false;
      final auth = firebase_auth.FirebaseAuth.instance;
      var firebaseUser = auth.currentUser;
      if (firebaseUser != null && !firebaseUser.isAnonymous) return false;
      firebaseUser ??= (await auth.signInAnonymously()).user;
      if (firebaseUser == null) return false;

      final idToken = await firebaseUser.getIdToken();
      if (idToken == null || idToken.isEmpty) return false;
      await _apiService.setAuthToken(idToken);
      await _apiService.syncUser(email: '');
      return true;
    } catch (e) {
      print('Anonymous session unavailable: $e');
      return false;
    }
  }

  /// True while the learner is on the automatic anonymous account.
  bool get isAnonymousSession {
    if (!AppConfig.anonymousSessionsEnabled) return false;
    try {
      if (Firebase.apps.isEmpty) return false;
      return firebase_auth.FirebaseAuth.instance.currentUser?.isAnonymous ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) {
    return firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // Turns a signed-in Firebase user (Apple or email) into an app account:
  // syncs it with the backend and caches it, falling back to the Firebase
  // data when the backend is unreachable.
  Future<User?> _completeFirebaseSignIn(
    firebase_auth.User firebaseUser,
    AuthProvider provider, {
    String fallbackName = '',
  }) async {
    // Apple hides the address behind a private relay for users who ask it to,
    // and sends nothing at all on repeat authorizations — Firebase keeps
    // whatever it was given the first time.
    final email = firebaseUser.email ?? '';
    final storedName = firebaseUser.displayName?.trim() ?? '';
    final displayName =
        storedName.isNotEmpty
            ? storedName
            : fallbackName.isNotEmpty
            ? fallbackName
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
      authProvider: provider,
    );
    final providerName = provider.name;

    // Sync even without an email: /auth/sync identifies the account from the
    // bearer token alone, and skipping it would leave the app "signed in"
    // with no server-side account at all.
    final idToken = await firebaseUser.getIdToken();
    if (idToken != null) {
      try {
        final result = await _apiService.firebaseAuth(
          uid: firebaseUser.uid,
          email: email,
          displayName: displayName,
          profileImageUrl: firebaseUser.photoURL,
          idToken: idToken,
          authProvider: providerName,
        );

        if (result != null) {
          final backendUser = User.fromJson(result['user']);
          _currentUser = backendUser;
          await _cacheUser(backendUser);
          return backendUser;
        }
        print('$providerName sign-in: backend sync returned no profile');
      } catch (apiError) {
        print('Backend API error during $providerName auth: $apiError');
        // Continue in offline mode with the Firebase data.
      }
    } else {
      print('$providerName sign-in: no Firebase ID token, skipping sync');
    }

    _currentUser = user;
    await _cacheUser(user);
    return user;
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
      final result = await signInOrLinkAnonymous(credential);
      return result.user?.getIdToken();
    } catch (e) {
      print('Firebase token exchange skipped: $e');
      return null;
    }
  }
}
