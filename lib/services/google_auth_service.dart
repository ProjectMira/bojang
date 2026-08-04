import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user.dart';
import 'app_config.dart';
import 'api_service.dart';

/// A native Apple authorization failure that would otherwise be mistaken for
/// the user dismissing the sheet.
///
/// AuthenticationServices uses code 1001 for both a real cancellation and the
/// server-side "Sign-Up Not Completed" screen. Release diagnostics preserve
/// that ambiguity but make the code, Apple message, and UTC time visible in a
/// tester screenshot so the incident can be correlated with Apple's logs.
class AppleSignInDiagnosticException implements Exception {
  AppleSignInDiagnosticException({
    required this.code,
    required this.message,
    DateTime? occurredAt,
  }) : occurredAt = (occurredAt ?? DateTime.now()).toUtc();

  final AuthorizationErrorCode code;
  final String message;
  final DateTime occurredAt;

  int get nativeCode => switch (code) {
    AuthorizationErrorCode.unknown => 1000,
    AuthorizationErrorCode.canceled => 1001,
    AuthorizationErrorCode.invalidResponse => 1002,
    AuthorizationErrorCode.notHandled => 1003,
    AuthorizationErrorCode.failed => 1004,
    _ => -1,
  };

  @override
  String toString() {
    final codeLabel = nativeCode < 0 ? code.name : '$nativeCode/${code.name}';
    final appleMessage = message.trim();
    return 'Apple authorization $codeLabel at '
        '${occurredAt.toIso8601String()}'
        '${appleMessage.isEmpty ? '' : ': $appleMessage'}';
  }
}

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

  // Sign in with Apple.
  //
  // This uses the native ASAuthorizationController sheet (via
  // sign_in_with_apple) and exchanges Apple's identity token for a Firebase
  // credential. We deliberately do NOT use
  // `FirebaseAuth.signInWithProvider(AppleAuthProvider())`: on iOS that opens
  // Firebase's *web* OAuth handler, which requires the project's Apple
  // provider to carry a Services ID, Team ID, Key ID and private key. A native
  // app has none of those, so that flow always ended in an error page — which
  // is what App Review hit. The credential flow below only needs the bundle ID
  // registered as the provider's client ID, which is already configured.
  Future<User?> signInWithApple() async {
    if (!AppConfig.firebaseEnabled) {
      print('Apple Sign-In requires Firebase, which is disabled in this build');
      return null;
    }

    try {
      // Generate a cryptographically random nonce. We pass the sha256 digest
      // to Apple's request sheet and the raw nonce to Firebase Auth credential.
      final rawNonce = _generateNonce();
      final nonceDigest = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonceDigest,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw StateError('Apple did not return an identity token');
      }

      final oauthCredential = firebase_auth.OAuthProvider(
        'apple.com',
      ).credential(idToken: identityToken, rawNonce: rawNonce);

      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(oauthCredential);
      final signedInUser = credential.user;
      if (signedInUser == null) return null;
      firebase_auth.User firebaseUser = signedInUser;

      // Apple only shares the name on the very first authorization, so persist
      // it to the Firebase profile while we have it.
      final appleFullName = [
            appleCredential.givenName,
            appleCredential.familyName,
          ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');
      if (appleFullName.isNotEmpty &&
          (firebaseUser.displayName?.trim().isEmpty ?? true)) {
        try {
          await firebaseUser.updateDisplayName(appleFullName);
          await firebaseUser.reload();
          firebaseUser =
              firebase_auth.FirebaseAuth.instance.currentUser ?? firebaseUser;
        } catch (nameError) {
          print('Could not persist Apple display name: $nameError');
        }
      }

      final idToken = await firebaseUser.getIdToken();
      // The email may be a private relay address when the user hides it, and
      // Apple omits it on repeat sign-ins — Firebase keeps the stored one.
      final email = appleCredential.email ?? firebaseUser.email ?? '';
      final displayName =
          appleFullName.isNotEmpty
              ? appleFullName
              : (firebaseUser.displayName?.trim().isNotEmpty ?? false)
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

      // Apple only returns an email on the first authorization, so a repeat
      // sign-in can legitimately have none. Sync regardless: /auth/sync
      // identifies the account from the bearer token, and skipping it would
      // leave the app "signed in" with no server-side account at all.
      if (idToken != null) {
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
          print('Apple sign-in: backend sync returned no profile');
        } catch (apiError) {
          print('Backend API error during Apple auth: $apiError');
          // Continue with offline mode
        }
      } else {
        print('Apple sign-in: no Firebase ID token, skipping backend sync');
      }

      // Use Apple data if backend is not available or failed
      _currentUser = user;
      await _cacheUser(user);
      return user;
    } on SignInWithAppleAuthorizationException catch (error) {
      // Always log the code and Apple's localized message, including for
      // `canceled`: when Apple itself refuses the sign-up (its sheet shows
      // "Sign-Up Not Completed"), dismissing that sheet arrives here as a
      // plain cancel, and this line is the only trace of what happened.
      print(
        'Apple Sign-In authorization error: ${error.code} — ${error.message}',
      );
      if (error.code == AuthorizationErrorCode.canceled) {
        print(
          'Note: If the iOS sheet showed "Sign-Up Not Completed", verify:\n'
          ' 1. Device: Settings -> Apple Account -> Sign-In & Security -> Apps Using Apple Account -> Bojang -> Stop Using Apple Account\n'
          ' 2. Developer Portal: Ensure "Sign in with Apple" is saved as Primary App ID for com.bojang.app\n'
          ' 3. Xcode: Re-sync Provisioning Profile',
        );
        if (AppConfig.appleSignInDiagnosticsEnabled) {
          throw AppleSignInDiagnosticException(
            code: error.code,
            message: error.message,
          );
        }
        return null;
      }
      rethrow;
    } on firebase_auth.FirebaseAuthException catch (error) {
      print('Apple Sign-In Firebase error: ${error.code} — ${error.message}');
      if (error.code == 'canceled' ||
          error.code == 'user-cancelled' ||
          error.code == 'web-context-cancelled') {
        return null;
      }
      rethrow;
    } catch (error) {
      print('Apple Sign-In error: $error');
      rethrow;
    }
  }

  // Cryptographically random nonce, in the URL-safe alphabet Apple accepts.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
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
