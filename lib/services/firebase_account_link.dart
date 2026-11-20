import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'analytics.dart';

/// Signs in with a Google or Apple [credential]. When the learner is still on
/// the anonymous account the app created at first launch, that account is
/// upgraded in place instead, so its uid — and the progress the backend
/// stored under it — carries over. If the identity already belongs to another
/// Bojang account, the learner is signed in to that account.
Future<firebase_auth.UserCredential> signInOrLinkAnonymous(
  firebase_auth.AuthCredential credential,
) async {
  final auth = firebase_auth.FirebaseAuth.instance;
  final current = auth.currentUser;
  if (current != null && current.isAnonymous) {
    try {
      final linked = await current.linkWithCredential(credential);
      Analytics.track('account_linked', {
        'provider': credential.providerId,
        'outcome': 'linked',
      });
      return linked;
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use' &&
          e.code != 'email-already-in-use') {
        rethrow;
      }
      Analytics.track('account_linked', {
        'provider': credential.providerId,
        'outcome': 'switched_to_existing',
      });
      return auth.signInWithCredential(e.credential ?? credential);
    }
  }
  Analytics.track('account_linked', {
    'provider': credential.providerId,
    'outcome': 'signed_in',
  });
  return auth.signInWithCredential(credential);
}
