import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../core/utils/logger.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/app_user.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/local_alerts_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';

/// Drives the Google sign-in screen.
///
/// On success it decides where to go: an existing complete profile → home,
/// otherwise → profile setup (seeding a stub profile with the Google name,
/// email, and photo so setup starts pre-filled).
class AuthController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();

  final RxBool busy = false.obs;

  Future<void> signInWithGoogle() async {
    if (busy.value) return;
    busy.value = true;
    try {
      final UserCredential cred = await _auth.signInWithGoogle();
      await _routeAfterSignIn(cred);
    } on AuthCancelled {
      // User backed out of the picker — no error toast needed.
      Log.d('Google sign-in cancelled by user');
    } on AuthFailure catch (e) {
      UiHelpers.error(e.message, title: 'Sign-in failed');
    } catch (e, s) {
      Log.e('unexpected sign-in error', error: e, stack: s);
      UiHelpers.error('Something went wrong. Please try again.');
    } finally {
      busy.value = false;
    }
  }

  /// After a successful sign-in, seed/refresh the profile stub and route.
  Future<void> _routeAfterSignIn(UserCredential cred) async {
    final User user = cred.user!;
    // Register for notifications + save FCM token (fire-and-forget).
    Get.find<NotificationService>().init();
    // Start client-side local alerts (free-plan push replacement).
    Get.find<LocalAlertsService>().start();
    try {
      final AppUser? existing = await _users.fetch(user.uid);

      if (existing != null && existing.isComplete) {
        Get.offAllNamed(Routes.home);
        return;
      }

      // New (or incomplete) user: create/merge a stub carrying Google data so
      // the profile-setup screen opens pre-filled.
      await _users.save(
        AppUser(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          photoUrl: user.photoURL,
          phone: user.phoneNumber ?? '',
        ),
        isNew: existing == null,
      );
      Get.offAllNamed(Routes.profileSetup);
    } catch (e, s) {
      Log.e('routing after sign-in failed', error: e, stack: s);
      UiHelpers.warning('Signed in, but we could not load your profile yet.');
      Get.offAllNamed(Routes.profileSetup);
    }
  }
}
