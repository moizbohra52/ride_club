import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/local_alerts_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';

/// Decides where the app starts:
///  - not logged in            → phone login
///  - logged in, no profile    → profile setup
///  - logged in, has profile   → home
///
/// Enforces a minimum splash duration so the transition never flickers, and
/// degrades gracefully if the profile lookup fails (assumes login screen).
class SplashController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final UserService _users = Get.find<UserService>();

  @override
  void onReady() {
    super.onReady();
    _decideNextRoute();
  }

  Future<void> _decideNextRoute() async {
    final Future<void> minDelay =
        Future<void>.delayed(AppConstants.splashMinDuration);

    String next = Routes.login;
    try {
      if (_auth.isLoggedIn) {
        final String uid = _auth.uid!;
        // Register for notifications + save FCM token (fire-and-forget).
        Get.find<NotificationService>().init();
        // Start client-side local alerts (free-plan push replacement).
        Get.find<LocalAlertsService>().start();
        final profile = await _users.fetch(uid);
        next = (profile != null && profile.isComplete)
            ? Routes.home
            : Routes.profileSetup;
      }
    } catch (e, s) {
      // Network/permission error reading profile — send to login so the user
      // can proceed rather than being stuck on the splash.
      Log.e('splash profile check failed', error: e, stack: s);
      next = _auth.isLoggedIn ? Routes.profileSetup : Routes.login;
    }

    await minDelay; // guarantee the splash is visible for the min duration
    Get.offAllNamed(next);
  }
}
