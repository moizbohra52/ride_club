import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/utils/logger.dart';

/// Wraps Firebase Google sign-in.
///
/// The [AuthController] calls [signInWithGoogle]; this service handles the
/// Google account picker, exchanges the tokens for a Firebase credential, and
/// signs in. All errors are mapped to short, user-facing messages.
///
/// Console requirements (see setup notes):
///  - Firebase Auth → Sign-in method → Google → Enabled.
///  - Android: the app's SHA-1 (and SHA-256) fingerprints registered on the
///    Firebase Android app, then a fresh google-services.json downloaded.
class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get uid => _auth.currentUser?.uid;

  /// Emits on login/logout so the app can react (used from Phase 2+).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Launch the Google account picker and sign in to Firebase.
  ///
  /// Returns the [UserCredential] on success. Throws [AuthFailure] (with an
  /// already-friendly message) on failure, or throws [AuthCancelled] if the
  /// user dismisses the account picker.
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Make sure no stale session blocks the picker.
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User backed out of the account chooser.
        throw const AuthCancelled();
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );

      return await _auth.signInWithCredential(credential);
    } on AuthCancelled {
      rethrow;
    } catch (e, s) {
      Log.e('Google sign-in failed', error: e, stack: s);
      throw AuthFailure(_mapError(e));
    }
  }

  /// Sign out of both Firebase and Google so the next sign-in shows the picker.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e, s) {
      Log.e('Google signOut failed (ignored)', error: e, stack: s);
    }
    await _auth.signOut();
  }

  /// Convert Firebase/Google/other errors into a short, user-facing message.
  String _mapError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using a different '
              'sign-in method.';
        case 'invalid-credential':
          return 'Could not verify your Google account. Please try again.';
        case 'operation-not-allowed':
          return 'Google sign-in is disabled for this project. Enable it in '
              'Firebase Console → Authentication → Sign-in method.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        case 'network-request-failed':
          return 'No internet connection. Check your network.';
        default:
          return e.message ?? 'Authentication failed (${e.code}).';
      }
    }
    final String s = e.toString();
    // google_sign_in surfaces platform errors like ApiException: 10 (SHA-1
    // mismatch) or 12500 (misconfiguration) via PlatformException.
    if (s.contains('ApiException: 10') || s.contains('10:')) {
      return 'Google sign-in is misconfigured (missing SHA-1). '
          'Register the app SHA-1 in Firebase Console.';
    }
    if (s.contains('12501') || s.contains('sign_in_canceled')) {
      return 'Sign-in was cancelled.';
    }
    if (s.contains('network') || s.contains('SocketException')) {
      return 'No internet connection. Check your network.';
    }
    return 'Google sign-in failed. Please try again.';
  }
}

/// User dismissed the Google account picker — not an error to shout about.
class AuthCancelled implements Exception {
  const AuthCancelled();
  @override
  String toString() => 'Sign-in cancelled';
}

/// A sign-in failure carrying an already-friendly, user-facing message.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}
