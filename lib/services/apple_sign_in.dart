import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/services.dart';

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
/// Step 2 goes through [channel] — `ios/Runner/AppleSignInBridge.swift` — and
/// not through the `sign_in_with_apple` package. The package reports only
/// Apple's error *code*, dropping the NSError chain that says why, and Apple
/// uses the same code (1001) for a user dismissing the sheet and for its own
/// refusal. Every failed sign-up so far has therefore looked like a cancel.
///
/// Two rules this flow must keep:
///
/// * Never `FirebaseAuth.signInWithProvider(AppleAuthProvider())`. On iOS that
///   is not native at all — it opens Firebase's *web* OAuth handler, which
///   needs the provider to carry a Services ID, Team ID, Key ID and private
///   key. A native app has none of those, so it always ends on an error page.
/// * Only the `fullName` scope is requested (in the bridge). Drokpo, which
///   works, asks for nothing else; asking for `email` additionally puts
///   Apple's private-relay consent step in the middle of the sheet, and the
///   sheet is where sign-up has been failing. Firebase still gets whatever
///   address Apple chooses to put in the identity token.
class AppleSignIn {
  const AppleSignIn();

  static const channel = MethodChannel('com.bojang.app/apple_sign_in');

  /// Runs the native sheet and returns the signed-in Firebase user.
  ///
  /// Returns null when the user dismisses the sheet. Throws
  /// [AppleSignInFailure] when Apple refuses the authorization and the build
  /// asks for that to be visible; see [AppleSignInFailure].
  Future<firebase_auth.User?> signIn({bool surfaceRefusals = false}) async {
    // Apple echoes the digest back inside the identity token; Firebase
    // re-hashes the raw nonce to check the pair, which is what stops a stolen
    // token from being replayed.
    final rawNonce = _randomNonce();

    final Map<Object?, Object?>? credential;
    try {
      credential = await channel.invokeMapMethod<Object?, Object?>(
        'requestCredential',
        {'nonce': _sha256(rawNonce)},
      );
    } on PlatformException catch (error) {
      final failure = AppleSignInFailure.fromPlatformException(error);
      // Log the whole chain, always: this is the only trace a refusal leaves.
      print('Apple authorization failed: ${failure.diagnostics}');
      if (failure.isCancellation && !surfaceRefusals) return null;
      throw failure;
    }

    if (credential == null) return null;

    final identityToken = credential['identityToken'] as String?;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError('Apple returned no identity token');
    }

    // Handing Firebase the name lets it populate displayName itself. Apple
    // only sends the name on the very first authorization, so there is no
    // second chance to pick it up.
    final appleCredential =
        firebase_auth.AppleAuthProvider.credentialWithIDToken(
          identityToken,
          rawNonce,
          firebase_auth.AppleFullPersonName(
            givenName: credential['givenName'] as String?,
            familyName: credential['familyName'] as String?,
          ),
        );

    final result = await firebase_auth.FirebaseAuth.instance
        .signInWithCredential(appleCredential);
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

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();
}

/// Apple would not complete the authorization.
///
/// A dismissal and a server-side refusal arrive as the same
/// `ASAuthorizationError` code, so the app normally stays silent on code 1001.
/// TestFlight builds turn it into a visible error instead: the [diagnostics]
/// string in a tester's — or App Review's — screenshot is the only evidence
/// available for correlating with Apple's logs.
class AppleSignInFailure implements Exception {
  AppleSignInFailure({
    required this.code,
    required this.message,
    this.domain = 'unknown',
    this.underlying = const [],
    DateTime? occurredAt,
  }) : occurredAt = (occurredAt ?? DateTime.now()).toUtc();

  /// Rebuilds the failure from what `AppleSignInBridge` put in `details`.
  factory AppleSignInFailure.fromPlatformException(PlatformException error) {
    final details = error.details;
    if (details is! Map) {
      return AppleSignInFailure(
        code: -1,
        message: error.message ?? error.code,
      );
    }

    // The chain is the point: AuthenticationServices wraps the error that
    // actually explains the refusal, usually an AKAuthenticationError.
    final chain = <String>[];
    Map<Object?, Object?>? nested = details['underlying'] as Map<Object?, Object?>?;
    while (nested != null) {
      chain.add('${nested['domain']} ${nested['code']}: '
          '${nested['localizedDescription']}');
      nested = nested['underlying'] as Map<Object?, Object?>?;
    }

    final info = details['userInfo'];
    if (info is Map && info.isNotEmpty) {
      chain.add(info.entries.map((e) => '${e.key}=${e.value}').join(', '));
    }

    return AppleSignInFailure(
      code: details['code'] as int? ?? -1,
      message:
          (details['localizedDescription'] as String?) ??
          error.message ??
          error.code,
      domain: (details['domain'] as String?) ?? 'unknown',
      underlying: chain,
    );
  }

  /// The `ASAuthorizationError` number, e.g. 1001.
  final int code;
  final String message;
  final String domain;

  /// Every error nested under the one Apple surfaced, outermost first.
  final List<String> underlying;
  final DateTime occurredAt;

  /// 1001 covers both a real dismissal and Apple refusing the sign-up, so this
  /// is "probably a cancel", not "certainly".
  bool get isCancellation => code == 1001;

  /// Everything known about the failure, for logs.
  String get diagnostics => [
    toString(),
    ...underlying.map((line) => '  ← $line'),
  ].join('\n');

  @override
  String toString() {
    final detail = message.trim();
    return 'Apple authorization $domain $code at '
        '${occurredAt.toIso8601String()}'
        '${detail.isEmpty ? '' : ': $detail'}'
        '${underlying.isEmpty ? '' : ' ← ${underlying.first}'}';
  }
}
