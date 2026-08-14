import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The native Sign in with Apple exchange, isolated from the rest of auth so
/// the flow can be read (and changed) in one place.
///
/// Modelled on the Drokpo iOS app's `AuthService.prepareAppleRequest` /
/// `completeAppleSignIn`, which is the same three steps:
///
///   1. mint a random nonce, send Apple its SHA-256 digest;
///   2. take the identity token out of the native ASAuthorization sheet;
///   3. hand Firebase (idToken, rawNonce, fullName) and sign in.
///
/// Two rules this flow must keep:
///
/// * Never `FirebaseAuth.signInWithProvider(AppleAuthProvider())`. On iOS that
///   is not native at all — it opens Firebase's *web* OAuth handler, which
///   needs the provider to carry a Services ID, Team ID, Key ID and private
///   key. A native app has none of those, so it always ends on an error page.
/// * Only the `fullName` scope is requested. Drokpo, which works, asks for
///   nothing else; asking for `email` additionally puts Apple's private-relay
///   consent step in the middle of the sheet, and the sheet is where sign-up
///   has been failing. Firebase still gets whatever address Apple chooses to
///   put in the identity token.
class AppleSignIn {
  const AppleSignIn();

  /// Runs the native sheet and returns the signed-in Firebase user.
  ///
  /// Returns null when the user dismisses the sheet. Throws
  /// [AppleSignInFailure] when Apple itself refuses the authorization and the
  /// build asks for that to be visible; see [AppleSignInFailure].
  Future<firebase_auth.User?> signIn({bool surfaceRefusals = false}) async {
    // Apple echoes the digest back inside the identity token; Firebase
    // re-hashes the raw nonce to check the pair, which is what stops a stolen
    // token from being replayed.
    final rawNonce = _randomNonce();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.fullName],
        nonce: _sha256(rawNonce),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      // AuthenticationServices reports a genuine dismissal and Apple's own
      // "Sign-Up Not Completed" refusal with the same code (1001), and the
      // plugin drops the underlying AKAuthenticationError. Log both, always:
      // without this line a refusal leaves no trace anywhere.
      print('Apple authorization ${error.code.name}: ${error.message}');
      if (error.code != AuthorizationErrorCode.canceled) rethrow;
      if (surfaceRefusals) {
        throw AppleSignInFailure(code: error.code, message: error.message);
      }
      return null;
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError('Apple returned no identity token');
    }

    // Handing Firebase the name lets it populate displayName itself. Apple
    // only sends the name on the very first authorization, so there is no
    // second chance to pick it up.
    final appleCredential = firebase_auth.AppleAuthProvider.credentialWithIDToken(
      identityToken,
      rawNonce,
      firebase_auth.AppleFullPersonName(
        givenName: credential.givenName,
        familyName: credential.familyName,
      ),
    );

    final result = await firebase_auth.FirebaseAuth.instance.signInWithCredential(
      appleCredential,
    );
    return result.user;
  }

  /// Nonce in the URL-safe alphabet Apple accepts.
  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}

/// Apple refused the authorization inside its own sheet.
///
/// Indistinguishable from a dismissal at the API level, so the app normally
/// stays silent. TestFlight builds turn it into a visible error instead: the
/// code and UTC timestamp in a tester's — or App Review's — screenshot are the
/// only evidence available for correlating with Apple's logs.
class AppleSignInFailure implements Exception {
  AppleSignInFailure({
    required this.code,
    required this.message,
    DateTime? occurredAt,
  }) : occurredAt = (occurredAt ?? DateTime.now()).toUtc();

  final AuthorizationErrorCode code;
  final String message;
  final DateTime occurredAt;

  /// The AuthenticationServices error number behind the plugin's enum.
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
    final label = nativeCode < 0 ? code.name : '$nativeCode/${code.name}';
    final detail = message.trim();
    return 'Apple authorization $label at ${occurredAt.toIso8601String()}'
        '${detail.isEmpty ? '' : ': $detail'}';
  }
}
