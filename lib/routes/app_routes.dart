/// Route name constants. Referenced everywhere via `Get.toNamed(Routes.x)`.
///
/// Future-phase routes are declared now so navigation code stays stable as the
/// app grows. Only the Phase 1 routes are registered in [app_pages] so far.
abstract class Routes {
  Routes._();

  // Phase 1
  static const String splash = '/splash';
  static const String login = '/login';
  static const String profileSetup = '/profile-setup';
  static const String home = '/home';

  // Phase 2 — home is now the rides tab shell; rideDetail opens one ride.
  static const String rideDetail = '/ride-detail';
  static const String editRide = '/edit-ride';
  static const String profile = '/profile';

  // Phase 3+ (registered as those phases land)
  static const String rideMap = '/ride-map';
  static const String chat = '/chat';
  static const String rideHistory = '/ride-history';
}
